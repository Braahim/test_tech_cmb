# Combo – Facturation à l'usage

Modèles de données permettant de calculer, **par compte et par semaine**, le nombre de locations
facturables, le nombre d'employés facturables et le revenu attendu selon la nouvelle grille tarifaire.

- **Stack** : Snowflake + dbt (1.9), architecture médaillon (bronze / silver / gold).
- **Sortie** : `COMBO_BILLING.GOLD.BILLING_ACCOUNT_WEEK` (Q1 + Q2), `GOLD.BILLING_LOCATION_WEEK` (détail) et `GOLD.BILLING_ACCOUNT_MONTH` (facture mensuelle simulée).
- **Qualité** : 105 tests dbt ; build complet PASS 117 / WARN 3 / ERROR 0 (15 modèles + 105 tests). Les 3 WARN signalent les contrats manquants de l'extrait (§5). La grille est testée contre tous les exemples chiffrés de l'énoncé.

---

## Sommaire

1. [Exécution](#1-exécution)
2. [Architecture](#2-architecture)
3. [Règles métier implémentées](#3-règles-métier-implémentées)
4. [Réponses aux questions](#4-réponses-aux-questions)
5. [Qualité des données (Q3)](#5-qualité-des-données-q3)
6. [Hypothèses](#6-hypothèses)
7. [Tests et contrôles](#7-tests-et-contrôles)
8. [Lecture métier](#8-lecture-métier)
9. [Limites et passage en production](#9-limites-et-passage-en-production)

---

## 1. Exécution

```sql
-- 1. Bronze brute : base, stage source, chargement des CSV (hors dbt)
--    Exécuter setup/01_bronze.sql

-- 2. Modèles et tests
EXECUTE DBT PROJECT FROM WORKSPACE "USER$"."PUBLIC"."DEFAULT$"
  PROJECT_ROOT = '/combo_billing/dbt'
  ARGS = 'build --target dev';
```

Hors Snowflake Workspaces : `cd dbt && dbt build` (renseigner `account` et `user` dans `profiles.yml`).

**Durée** : environ 20 secondes pour 15 modèles et 105 tests.

**Documentation** : `dbt docs generate`. Les descriptions sont aussi poussées en `COMMENT` Snowflake (`persist_docs`), visibles dans Snowsight sur chaque table et colonne.

---

## 2. Architecture

```
@TEST_TECH.DOCS.DATA ──COPY FILES──► BRONZE.SRC_FILES (stage)
                                        │ COPY INTO (setup/01_bronze.sql)
                                        ▼
                                     BRONZE.STG_*      copie brute, tout en VARCHAR + traçabilité
                                        │ dbt
                                        ▼
                                     BRONZE.<TABLE>    typage et nettoyage 1 pour 1, sans règle métier
                                        │ dbt
                                        ▼
                                     SILVER.*          logique métier de facturation
                                        │ dbt
                                        ▼
                                     GOLD.*            vues exposées, contrat de colonnes et de types
```

| Couche | Objet | Grain | Rôle |
|---|---|---|---|
| BRONZE | `SRC_FILES` | fichier | Stage interne : les 6 CSV sources |
| BRONZE | `STG_ACCOUNTS` … `STG_RESTS` | ligne de CSV | Copie brute (VARCHAR), `_source_file`, `_source_row`, `_loaded_at` |
| BRONZE | `ACCOUNTS`, `LOCATIONS`, `MEMBERSHIPS`, `USER_CONTRACTS`, `SHIFTS`, `RESTS` | 1 pour 1 | Types, booléens et dates normalisés, colonnes utiles uniquement |
| SILVER | `CONTRACTS_RESOLVED` | contrat | Contrats du fichier + contrats d'origine reconstruits depuis leurs avenants |
| SILVER | `WEEKS` | semaine | Calendrier lundi → lundi (UTC), borné par les données, `WEEK_STATUS` |
| SILVER | `PLANNING_WEEKS` | contrat × semaine | Shifts et repos éclatés sur chaque semaine touchée, rattachés à l'établissement |
| SILVER | `BILLING_LOCATION_WEEK` | établissement × semaine | Employés facturables, taille, prix |
| SILVER | `BILLING_ACCOUNT_WEEK` | compte × semaine | Somme des établissements + planning non rattaché |
| SILVER | `BILLING_ACCOUNT_MONTH` | compte × mois | Facture mensuelle : moyenne des semaines complètes du mois |
| GOLD | `BILLING_ACCOUNT_WEEK` | compte × semaine | **Q1 + Q2**, contrat exposé |
| GOLD | `BILLING_LOCATION_WEEK` | établissement × semaine | Détail de la facture |
| GOLD | `BILLING_ACCOUNT_MONTH` | compte × mois | Facture mensuelle simulée |

**Conventions**
- Le schéma porte la couche, le nom porte le sens métier. Seul préfixe : `STG_` (« vient du stage »).
- Fichiers dbt préfixés par couche (`silver_weeks.sql`), objets Snowflake sans préfixe (`alias`).
- Colonnes techniques préfixées par `_` (`_source_file`, `_source_row`, `_ingestion_timestamp`).
- Jamais de `SELECT *`. Aucune utilisation de `CURRENT_DATE` : la logique temporelle repose sur la variable `extraction_date`.
- Toute la logique métier est en silver ; si la grille change, seule la macro `pricing.sql` est modifiée.

Schéma détaillé et vulgarisé : [docs/modele_de_donnees.md](docs/modele_de_donnees.md)

---

## 3. Règles métier implémentées

| Règle (énoncé) | Implémentation |
|---|---|
| Semaine du lundi 00:00 au dimanche 23:59:59 UTC | `SILVER.WEEKS` : `[lundi 00:00, lundi suivant 00:00[`, calculé avec `DAYOFWEEKISO` (indépendant du paramètre `WEEK_START` du compte) |
| Employé facturable = au moins un shift **ou** un repos dans la semaine | Shifts et repos réunis dans `PLANNING_WEEKS` ; un événement compte sur **chaque** semaine qu'il chevauche (`starts_at < fin_semaine AND ends_at > début_semaine`) |
| Compté sur la location **du contrat** | Le planning ne porte pas de location : le rattachement passe obligatoirement par le contrat |
| Location facturable = non archivée | `BILLING_LOCATION_WEEK` : `NOT is_archived`, y compris à 0 employé (tarif Micro, 0-5 employés) |
| Taille déterminée par les employés facturables de la semaine | `COUNT(DISTINCT membership_id)` par établissement et par semaine |
| Grille : 60 / 80 / 216 € + 4 € du 7ème au 39ème + 2,4 € à partir du 40ème | Macro `pricing.sql`, testée par `assert_pricing_grid.sql` |
| Revenu du compte | **Somme des établissements**, jamais la grille appliquée au total du compte |

---

## 4. Réponses aux questions

Tables : `COMBO_BILLING.GOLD.BILLING_ACCOUNT_WEEK` (une ligne par compte et par semaine).

### Q1 – Locations et employés facturables par compte et par semaine

```sql
SELECT account_id, account_name, week_start, n_billable_locations, n_billable_employees
FROM combo_billing.gold.billing_account_week
WHERE week_status = 'complete'
ORDER BY account_id, week_start;
```

### Q2 – Revenu hebdomadaire attendu par compte

```sql
SELECT account_id, account_name, week_start, expected_revenue, n_unassigned_contracts
FROM combo_billing.gold.billing_account_week
WHERE week_status = 'complete'
ORDER BY account_id, week_start;
```

Le revenu hebdomadaire est la grille appliquée aux employés de la semaine, **sans division** : le processus aval
fait la moyenne des semaines du mois (exemple de l'énoncé : le Laboratoire facturé 156 € « cette semaine-là »).

### Prolongement – Facture mensuelle simulée

```sql
SELECT account_id, account_name, billing_month, n_weeks_billed, monthly_invoice
FROM combo_billing.gold.billing_account_month
WHERE month_status = 'complete'
ORDER BY account_id, billing_month;
```

Moyenne des semaines complètes du mois, comme le processus aval décrit dans l'énoncé. Une semaine appartient
au mois qui contient son jeudi (ISO 8601). Un mois n'est `complete` que si toutes ses semaines le sont :
11 mois complets, de mai 2023 à mars 2024. Mars 2024 : 13 246,40 € pour 30 comptes (441,55 € en moyenne).

### Synthèse (52 semaines complètes, du 10/04/2023 au 07/04/2024)

| Indicateur | Valeur |
|---|---|
| Comptes | 30 |
| Établissements facturables | 152 (15 archivés exclus) |
| Revenu total calculé | 509 681,60 € |
| Revenu hebdomadaire moyen (tous comptes) | 9 801,60 € |
| Moyenne par compte et par semaine | 4,6 établissements, 32 employés |
| Répartition des semaines-établissement | 3 443 Micro · 2 639 Petit · 35 Grand |
| Couples (contrat, semaine) non rattachés, non facturés | 50 259 |

Le revenu calculé est une **estimation basse** : une partie du planning n'a pas pu être rattachée à un établissement (voir §5).

### Statut des semaines

| `WEEK_STATUS` | Semaines | Usage |
|---|---|---|
| `partial_start` | 1 (03/04/2023) | Données à partir du samedi 08/04 : à exclure |
| `complete` | 52 | **Base de la facture** |
| `in_progress` | 1 (08/04/2024) | Semaine de l'extraction : à exclure |
| `provisional` | 4 (15/04 → 06/05/2024) | Planning saisi à l'avance, incomplet (de ~2 000 à 459 contrats planifiés) : prévision uniquement |

---

## 5. Qualité des données (Q3)

| # | Anomalie | Mesure | Traitement |
|---|---|---|---|
| 1 | **Planning rattaché à un contrat absent de l'extrait** | 296 156 shifts (61 %) et 123 400 repos (64 %) | Les contrats d'origine sont reconstruits depuis leurs avenants quand c'est possible (194 contrats, 8 760 couples contrat-semaine récupérés). Le reste est **compté à part** (`N_UNASSIGNED_CONTRACTS`) et **non facturé** : sans contrat, l'établissement est inconnu et le prix, qui dépend de l'établissement, ne peut pas être calculé sans l'inventer. Test `relationships` en `warn`. |
| 2 | **Avenants** : le planning pointe vers le contrat d'origine, jamais vers l'avenant | 492 avenants, 0 shift posé sur un avenant | `CONTRACTS_RESOLVED`. Garde-fou : `assert_rebuilt_contracts_unambiguous` (aucun original n'a d'avenants vers 2 personnes ou 2 établissements). |
| 3 | **Booléens dans 10 formats** | `true/True/TRUE/1/yes`, `false/False/FALSE/0/no` | `TRY_TO_BOOLEAN` ; une valeur inconnue devient NULL et fait échouer un test `not_null`. |
| 4 | **Dates de contrat dans 2 formats** | 201 `contract_start` en `JJ/MM/AAAA` | Formats explicites. En lecture automatique, **123 dates (jour ≤ 12) auraient été inversées sans erreur** (`05/03/2024` lu le 3 mai). |
| 5 | **Temps de travail dans 4 formats** | `40.0`, ` 39.99 ` (198 avec espaces), `35h` (341), `35,0` (160) ; 249 NULL | Normalisation en nombre d'heures (`CONTRACT_HOURS_PER_WEEK`). Non utilisé par la facturation. |
| 6 | **Repos très longs** | 25 869 repos de plus de 24 h, jusqu'à 366 jours ; 34 632 traversent une semaine | Comptés sur **chaque** semaine touchée (+4,7 % de couples contrat-semaine par rapport à la seule semaine de début). Justification : exemple du Laboratoire (« arrêt maladie **non saisi** »). |
| 7 | **Une personne planifiée sur deux établissements la même semaine** | 37 cas (34 personnes) | Facturée sur chacun (règle de l'énoncé) ; le total d'employés du compte est la somme des établissements, comme dans l'exemple (« total 55 »). |
| 8 | **Planning antérieur à la création de l'établissement** | 169 lignes, 9 établissements | Un établissement est facturé à partir de sa création **ou** de sa première planification si elle est antérieure. |
| 9 | **`updated_at` pollué par une mise à jour en masse** | 18/07/2023 : 39 établissements modifiés en 10 minutes, sur au moins 13 comptes | Écarté comme date d'archivage : `archived` est appliqué comme un état courant. |
| 10 | **`archived` sans date** (soft delete) | 15 établissements archivés, aucun avec du planning rattaché | Exclus de toutes les semaines ; impact nul dans cet extrait. |
| 11 | **Semaines incomplètes** | Données du samedi 08/04/2023 au mardi 07/05/2024 ; extraction le 08/04/2024 | `WEEK_STATUS` ; seules les semaines `complete` alimentent la facture. |
| 12 | **`planification_type` vide** | 15 195 shifts | Sans impact (le type ne change pas la facturabilité). |
| 13 | **Contrats sans membership connu** | 4 contrats | Conservés (le `membership_id` est présent, seule la fiche est absente). Test `relationships` en `warn`. |

---

## 6. Hypothèses

| Hypothèse | Justification |
|---|---|
| Un employé = un `membership_id` | `memberships.csv` est décrit comme « les employés » ; deux contrats d'une même personne sur un établissement ne comptent qu'une fois. |
| Un repos compte sur toutes les semaines qu'il touche, quel que soit son type | « Le type de planification n'a pas d'importance » ; exemple du Laboratoire. |
| Un établissement non archivé sans employé est facturé 60 € | Tranche Micro « 0-5 employés », la seule condition de facturabilité étant `archived = false`. |
| Shifts `unscheduled`, `did_not_show`, membership inactif, planning hors dates de contrat : facturables | La règle ne retient que « planifié au moins une fois ». |
| Un avenant porte la même personne et le même établissement que son contrat d'origine | Non vérifiable (l'original est absent) ; verrouillé par un test. Une mutation entre établissements serait mal attribuée. |
| Date de référence = date d'extraction (08/04/2024), jamais la date du jour | Déduite du dernier `updated_at` ; vérifiée par `assert_extraction_date_matches_data`. Garantit des résultats identiques quelle que soit la date d'exécution. |

---

## 7. Tests et contrôles

| Type | Exemples |
|---|---|
| Génériques (`unique`, `not_null`, `accepted_values`, `relationships`) | Clés de chaque table, valeurs de statut, rattachements |
| **Grille tarifaire** (`assert_pricing_grid`) | Tous les exemples chiffrés de l'énoncé (60, 96, 156, 176, 374,4 €) + bornes 0 / 6 / 39 / 40 |
| Grain (`assert_*_grain`) | Une ligne par contrat-semaine, établissement-semaine, compte-semaine, compte-mois |
| **Réconciliation** (`assert_account_revenue_reconciles`) | Somme des comptes = somme des établissements (rien perdu, rien dupliqué) |
| Hypothèses (`assert_rebuilt_contracts_unambiguous`, `assert_extraction_date_matches_data`) | Le build échoue si une hypothèse devient fausse |
| Contrats de modèle (gold) | Noms et types des colonnes des 3 vues exposées vérifiés à chaque build |
| Contrôles indépendants (`analyses/sanity_checks.sql`) | Aucun trou de semaine, prix cohérent avec la taille, repos long éclaté (10/10 semaines), shift dimanche-lundi (2/2), recalcul manuel depuis la bronze d'un établissement à 40 employés (350,4 €) |

---

## 8. Lecture métier

Calculs reproductibles : [`dbt/analyses/business_insights.sql`](dbt/analyses/business_insights.sql) (semaines complètes).

**Impact de la migration.** À usage égal, l'ancienne grille (49 / 99 / 199 / 299 €) aurait produit 515 809 €,
contre 509 682 € pour la nouvelle (−1,2 %). La migration est quasi neutre en volume mais **redistribue** :
10 comptes paient plus de 10 % de plus, 13 paient plus de 10 % de moins. Les comptes à gros établissements baissent (jusqu'à −31 %) ; ceux qui ont de nombreux établissements peu peuplés ou vides augmentent (l'ancienne grille ne facturait pas un établissement sans employé). Ce calcul est le meilleur cas de
l'ancien modèle : en réalité, l'ancien prix était figé à la signature, donc le gain réel de la migration est supérieur
(non mesurable sans les prix contractuels historiques).
→ Les 10 comptes en hausse sont à accompagner par l'équipe commerciale avant la première facture.

**Établissements jamais planifiés.** 35 établissements non archivés n'ont aucun employé planifié sur la période :
ils représentent 61 320 € (12 % du revenu calculé), facturés au tarif Micro.
→ Risque de contestation ; campagne d'archivage recommandée avant la bascule.

**Effet de seuil à 40 employés.** Passer de 39 à 40 employés fait passer la semaine de 212 € à 350,4 € (+65 %),
la base Grand s'ajoutant aux 33 suppléments à 4 €. 5 établissements oscillent entre 37 et 42 employés.
→ Factures volatiles pour ces clients ; un lissage ou une alerte est à étudier.

**Équité perçue.** Le prix moyen par employé et par semaine est de 11,99 €, mais varie de 6,39 € à 87,69 € selon le compte
(rapport de 1 à 14). Les comptes multi-établissements peu peuplés paient le plus cher par personne ; l'écart est accentué
par le planning non rattaché, qui réduit le nombre d'employés comptés.
→ Point de vigilance pour la communication commerciale : le nouveau modèle facture l'étendue du client, pas seulement sa taille.

**Concentration.** Les 5 premiers comptes représentent 43,6 % du revenu calculé.
→ Comptes à accompagner en priorité lors de la migration.

**Coût de la qualité des données.** Le planning non rattaché représente au minimum 4 € par contrat et par semaine non facturés.
→ Fiabiliser l'extraction des contrats est un levier de revenu direct.

---

## 9. Limites et passage en production

**Limites**
- Revenu sous-estimé tant que les contrats manquants ne sont pas fournis.
- `archived` étant un état courant, un établissement archivé récemment disparaît aussi de son historique.
- Les semaines postérieures à l'extraction sont incomplètes par nature.
- **La sous-estimation n'est pas uniforme dans le temps.** La part de planning non rattaché passe de 72 % (T2 2023)
  à 42 % (T2 2024) : les contrats de l'extrait sont surtout récents. Le revenu hebdomadaire passe de 7 253 € à 13 356 €,
  mais cette hausse combine une croissance réelle (99 → 152 établissements) et cet artefact. Les montants de mois
  différents ne doivent donc pas être comparés comme une tendance.

**Passage en production**
- **Bronze** : `SHIFTS` et `RESTS` en `incremental` (`unique_key` sur l'id, filtre sur `updated_at`) pour intégrer les modifications, pas seulement les ajouts.
- **Silver** : recalcul sur une fenêtre glissante (par exemple 8 semaines), le planning étant modifié rétroactivement ; au-delà, les semaines sont closes.
- **Établissements** : `dbt snapshot` (SCD2) sur `LOCATIONS` pour historiser `archived` et obtenir une date d'archivage.
- **Suppressions** : un shift supprimé dans l'application doit sortir de la facture (flag de suppression ou comparaison complète périodique).
- **Environnements** : une base par environnement (`COMBO_BILLING_DEV` / `_PROD`) et des targets dbt séparées.
- **Chargement** : `MATCH_BY_COLUMN_NAME` ou contrôle de l'en-tête des CSV, le chargement positionnel étant sensible à l'ordre des colonnes.

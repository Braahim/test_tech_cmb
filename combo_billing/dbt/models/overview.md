{% docs __overview__ %}

# Combo – Facturation à l'usage

Data product de facturation : calcule, **par compte et par semaine**, les établissements facturables,
les employés facturables et le revenu attendu selon la nouvelle grille tarifaire, ainsi que la facture
mensuelle simulée.

## Consommateurs

Processus de facturation mensuelle et équipe finance. Point d'accès unique : le schéma **GOLD**.

| Objet | Grain | Usage |
|---|---|---|
| `GOLD.BILLING_ACCOUNT_WEEK` | compte × semaine | Questions 1 et 2 |
| `GOLD.BILLING_LOCATION_WEEK` | établissement × semaine | Détail de la facture |
| `GOLD.BILLING_ACCOUNT_MONTH` | compte × mois | Facture mensuelle simulée |

## Pipeline

`BRONZE.STG_*` (copie brute) → `BRONZE.<TABLE>` (typage) → `SILVER` (logique métier) → `GOLD` (contrat exposé).

## Règles d'usage

- Facturer uniquement `WEEK_STATUS = 'complete'` et `MONTH_STATUS = 'complete'`.
- Le revenu est une **estimation basse** : le planning rattaché à un contrat absent de l'extrait est compté
  (`N_UNASSIGNED_CONTRACTS`) mais non facturé.
- Date de référence : extraction du 08/04/2024 (variable `extraction_date`).

{% enddocs %}

-- Lecture métier des résultats (semaines complètes). Compilation : dbt compile --select business_insights
-- 1. Impact de la migration : ancienne grille (49/99/199/299 €) appliquée au même usage, par compte
-- 2. Établissements jamais planifiés mais facturés (60 €/semaine)
-- 3. Établissements proches du seuil de 40 employés (212 € → 350,4 €)

WITH lw AS (
    SELECT *
    FROM {{ ref('silver_billing_location_week') }}
    WHERE week_status = 'complete'
),

-- 1. Ancienne grille au même usage (hypothèse : 0 employé = 0 €, la grille commence à 1)
priced AS (
    SELECT
        account_id,
        location_price AS new_price,
        CASE
            WHEN n_billable_employees = 0  THEN 0
            WHEN n_billable_employees <= 5  THEN 49
            WHEN n_billable_employees <= 10 THEN 99
            WHEN n_billable_employees <= 30 THEN 199
            ELSE 299
        END AS old_price
    FROM lw
),

by_account AS (
    SELECT account_id, SUM(new_price) AS new_revenue, SUM(old_price) AS old_revenue
    FROM priced
    GROUP BY account_id
),

-- 2. Établissements sans aucun employé facturable sur toute la période
never_planned AS (
    SELECT location_id
    FROM lw
    GROUP BY location_id
    HAVING MAX(n_billable_employees) = 0
)

SELECT
    (SELECT SUM(new_revenue) FROM by_account)                               AS new_model_revenue,
    (SELECT SUM(old_revenue) FROM by_account)                               AS old_grid_same_usage_revenue,
    (SELECT COUNT_IF(new_revenue > old_revenue * 1.10) FROM by_account)     AS accounts_paying_10pct_more,
    (SELECT COUNT_IF(new_revenue < old_revenue * 0.90) FROM by_account)     AS accounts_paying_10pct_less,
    (SELECT COUNT(*) FROM never_planned)                                    AS never_planned_locations,
    (SELECT SUM(location_price) FROM lw
      WHERE location_id IN (SELECT location_id FROM never_planned))         AS never_planned_revenue,
    (SELECT COUNT(DISTINCT location_id) FROM lw
      WHERE n_billable_employees BETWEEN 37 AND 42)                         AS locations_near_40_threshold

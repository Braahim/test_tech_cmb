-- SILVER.BILLING_ACCOUNT_WEEK : une ligne par compte et par semaine. Répond aux questions 1 et 2.
-- Somme des établissements (le prix n'est jamais recalculé au niveau du compte) + planning non rattaché, compté à part.

{{ config(alias='BILLING_ACCOUNT_WEEK') }}

-- 1. Facturation : somme des établissements du compte
WITH billed AS (
    SELECT
        account_id,
        week_start,
        COUNT(*)                  AS n_billable_locations,
        SUM(n_billable_employees) AS n_billable_employees,
        SUM(location_price)       AS expected_revenue
    FROM {{ ref('silver_billing_location_week') }}
    GROUP BY account_id, week_start
),

-- 2. Planning sans établissement connu : compté, non facturé (personne inconnue → contrats distincts)
unassigned AS (
    SELECT
        account_id,
        week_start,
        COUNT(DISTINCT user_contract_id) AS n_unassigned_contracts
    FROM {{ ref('silver_planning_weeks') }}
    WHERE NOT is_assigned
    GROUP BY account_id, week_start
),

-- 3. Union des deux : une semaine peut n'avoir que du planning non rattaché
account_weeks AS (
    SELECT
        COALESCE(b.account_id, u.account_id) AS account_id,
        COALESCE(b.week_start, u.week_start) AS week_start,
        COALESCE(b.n_billable_locations, 0)  AS n_billable_locations,
        COALESCE(b.n_billable_employees, 0)  AS n_billable_employees,
        COALESCE(b.expected_revenue, 0)      AS expected_revenue,
        COALESCE(u.n_unassigned_contracts, 0) AS n_unassigned_contracts
    FROM billed AS b
    FULL OUTER JOIN unassigned AS u
        ON  u.account_id = b.account_id
        AND u.week_start = b.week_start
)

-- 4. Statut de la semaine : seules les semaines 'complete' alimentent la facture
SELECT
    aw.account_id,
    aw.week_start,
    w.week_status,
    aw.n_billable_locations,
    aw.n_billable_employees,
    aw.expected_revenue,
    aw.n_unassigned_contracts
FROM account_weeks AS aw
INNER JOIN {{ ref('silver_weeks') }} AS w
    ON w.week_start = aw.week_start

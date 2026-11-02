-- SILVER.BILLING_ACCOUNT_MONTH : facture mensuelle simulée, une ligne par compte et par mois.
-- Facture = moyenne des semaines complètes du mois (processus aval décrit dans l'énoncé).
-- Une semaine appartient au mois qui contient son jeudi (ISO 8601 : mois où elle a la majorité de ses jours).

{{ config(alias='BILLING_ACCOUNT_MONTH') }}

-- 1. Rattachement de chaque semaine à un mois de facturation
WITH weeks AS (
    SELECT
        week_start,
        week_status,
        DATE_TRUNC('month', DATEADD('day', 3, week_start))::DATE AS billing_month
    FROM {{ ref('silver_weeks') }}
),

-- 2. Statut du mois : complet seulement si toutes ses semaines le sont
months AS (
    SELECT
        billing_month,
        COUNT(*)                            AS n_weeks_in_month,
        COUNT_IF(week_status = 'complete')  AS n_complete_weeks,
        IFF(COUNT(*) = COUNT_IF(week_status = 'complete'), 'complete', 'incomplete') AS month_status
    FROM weeks
    GROUP BY billing_month
),

-- 3. Moyenne des semaines complètes du mois, par compte
account_months AS (
    SELECT
        w.billing_month,
        b.account_id,
        COUNT(*)                    AS n_weeks_billed,
        AVG(b.n_billable_locations) AS avg_billable_locations,
        AVG(b.n_billable_employees) AS avg_billable_employees,
        AVG(b.expected_revenue)     AS monthly_invoice,
        AVG(b.n_unassigned_contracts) AS avg_unassigned_contracts
    FROM {{ ref('silver_billing_account_week') }} AS b
    INNER JOIN weeks AS w
        ON w.week_start = b.week_start
    WHERE b.week_status = 'complete'
    GROUP BY w.billing_month, b.account_id
)

SELECT
    am.account_id,
    am.billing_month,
    m.month_status,
    am.n_weeks_billed,
    m.n_weeks_in_month,
    am.avg_billable_locations,
    am.avg_billable_employees,
    am.monthly_invoice,
    am.avg_unassigned_contracts
FROM account_months AS am
INNER JOIN months AS m
    ON m.billing_month = am.billing_month

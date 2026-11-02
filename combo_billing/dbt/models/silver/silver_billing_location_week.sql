-- SILVER.BILLING_LOCATION_WEEK : une ligne par établissement facturable et par semaine, avec son prix.
-- Le prix se calcule par établissement (jamais sur le total du compte), y compris à 0 employé (micro).

{{ config(alias='BILLING_LOCATION_WEEK') }}

-- 1. Employés facturables : personnes distinctes planifiées sur l'établissement de leur contrat
WITH employees_by_location_week AS (
    SELECT
        location_id,
        week_start,
        COUNT(DISTINCT membership_id) AS n_billable_employees
    FROM {{ ref('silver_planning_weeks') }}
    WHERE is_assigned
    GROUP BY location_id, week_start
),

-- 2. Établissements facturables (non archivés), à partir de leur création ou de leur première planification
billable_locations AS (
    SELECT
        l.location_id,
        l.account_id,
        LEAST(
            DATEADD('day', 1 - DAYOFWEEKISO(l.created_at), l.created_at::DATE),
            COALESCE(MIN(e.week_start), '9999-12-31'::DATE)
        ) AS billing_start_week
    FROM {{ ref('bronze_locations') }} AS l
    LEFT JOIN employees_by_location_week AS e
        ON e.location_id = l.location_id
    WHERE NOT l.is_archived
    GROUP BY l.location_id, l.account_id, l.created_at
),

-- 3. Établissements × semaines : les semaines sans planning restent présentes (0 employé)
location_weeks AS (
    SELECT
        bl.location_id,
        bl.account_id,
        w.week_start,
        w.week_status,
        COALESCE(e.n_billable_employees, 0) AS n_billable_employees
    FROM billable_locations AS bl
    INNER JOIN {{ ref('silver_weeks') }} AS w
        ON w.week_start >= bl.billing_start_week
    LEFT JOIN employees_by_location_week AS e
        ON  e.location_id = bl.location_id
        AND e.week_start  = w.week_start
)

-- 4. Application de la grille tarifaire
SELECT
    location_id,
    account_id,
    week_start,
    week_status,
    n_billable_employees,
    {{ location_size('n_billable_employees') }}  AS location_size,
    {{ location_price('n_billable_employees') }} AS location_price
FROM location_weeks

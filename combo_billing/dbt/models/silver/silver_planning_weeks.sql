-- SILVER.PLANNING_WEEKS : une ligne par contrat et par semaine où il est planifié (au moins un shift OU un repos).
-- Un événement compte sur chaque semaine qu'il touche (repos longs, shifts du dimanche soir au lundi).

{{ config(alias='PLANNING_WEEKS') }}

-- 1. Shifts et repos réunis : le type de planification n'a pas d'importance pour la facturation
WITH planning AS (
    SELECT user_contract_id, account_id, starts_at, ends_at, 'shift' AS planning_source
    FROM {{ ref('bronze_shifts') }}
    UNION ALL
    SELECT user_contract_id, account_id, starts_at, ends_at, 'rest' AS planning_source
    FROM {{ ref('bronze_rests') }}
),

-- 2. Éclatement : chaque événement sur toutes les semaines qu'il chevauche (fin de semaine exclue)
planning_by_week AS (
    SELECT
        p.user_contract_id,
        w.week_start,
        ANY_VALUE(p.account_id)                 AS account_id,
        COUNT_IF(p.planning_source = 'shift')   AS n_shifts,
        COUNT_IF(p.planning_source = 'rest')    AS n_rests
    FROM planning AS p
    INNER JOIN {{ ref('silver_weeks') }} AS w
        ON  p.starts_at < w.week_end
        AND p.ends_at   > w.week_start
    GROUP BY p.user_contract_id, w.week_start
)

-- 3. Rattachement à la personne et à l'établissement du contrat (NULL si contrat introuvable)
SELECT
    pw.user_contract_id,
    pw.week_start,
    pw.account_id,
    c.membership_id,
    c.location_id,
    COALESCE(c.resolution_source, 'unassigned') AS resolution_source,
    c.user_contract_id IS NOT NULL              AS is_assigned,
    pw.n_shifts,
    pw.n_rests
FROM planning_by_week AS pw
LEFT JOIN {{ ref('silver_contracts_resolved') }} AS c
    ON c.user_contract_id = pw.user_contract_id

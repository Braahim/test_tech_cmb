-- Contrôles indépendants des modèles (hors tests dbt). Compilation : dbt compile --select sanity_checks
-- Chaque colonne doit valoir 0, sauf c3 / c4 qui affichent attendu / trouvé.

WITH lw AS (
    SELECT * FROM {{ ref('silver_billing_location_week') }}
),

-- c1. Aucun trou : chaque établissement a une ligne pour chaque semaine depuis son début
gaps AS (
    SELECT location_id
    FROM lw
    GROUP BY location_id
    HAVING COUNT(*) <> DATEDIFF('week', MIN(week_start), MAX(week_start)) + 1
),

-- c2. Prix cohérent avec la taille
bad_prices AS (
    SELECT location_id
    FROM lw
    WHERE (location_size = 'micro' AND location_price <> 60)
       OR (location_size = 'small' AND location_price NOT BETWEEN 80 AND 212)
       OR (location_size = 'large' AND location_price < 350.4)
),

-- c3. Un repos de 2 à 3 mois produit une ligne par semaine touchée
long_rest AS (
    SELECT
        rest_id,
        user_contract_id,
        starts_at,
        ends_at,
        DATEDIFF(
            'week',
            DATEADD('day', 1 - DAYOFWEEKISO(starts_at), starts_at::DATE),
            DATEADD('day', 1 - DAYOFWEEKISO(DATEADD('second', -1, ends_at)), DATEADD('second', -1, ends_at)::DATE)
        ) + 1 AS expected_weeks
    FROM {{ ref('bronze_rests') }}
    WHERE DATEDIFF('day', starts_at, ends_at) BETWEEN 60 AND 90
      AND ends_at < '2024-04-01'
    ORDER BY rest_id
    LIMIT 1
),

long_rest_check AS (
    SELECT lr.expected_weeks, COUNT(pw.week_start) AS found_weeks
    FROM long_rest AS lr
    LEFT JOIN {{ ref('silver_planning_weeks') }} AS pw
        ON  pw.user_contract_id = lr.user_contract_id
        AND pw.week_start >= DATEADD('day', 1 - DAYOFWEEKISO(lr.starts_at), lr.starts_at::DATE)
        AND pw.week_start <  lr.ends_at
    GROUP BY lr.expected_weeks
),

-- c4. Un shift du dimanche soir au lundi compte sur les deux semaines
sunday_shift AS (
    SELECT user_contract_id, starts_at
    FROM {{ ref('bronze_shifts') }}
    WHERE DAYOFWEEKISO(starts_at) = 7
      AND DAYOFWEEKISO(ends_at) = 1
      AND ends_at::TIME > '00:00:00'
    ORDER BY shift_id
    LIMIT 1
),

sunday_shift_check AS (
    SELECT COUNT(*) AS found_weeks
    FROM sunday_shift AS s
    INNER JOIN {{ ref('silver_planning_weeks') }} AS pw
        ON  pw.user_contract_id = s.user_contract_id
        AND pw.week_start IN (
            DATEADD('day', 1 - DAYOFWEEKISO(s.starts_at), s.starts_at::DATE),
            DATEADD('day', 8 - DAYOFWEEKISO(s.starts_at), s.starts_at::DATE)
        )
)

SELECT
    (SELECT COUNT(*) FROM gaps)                                              AS c1_locations_with_gaps,
    (SELECT COUNT(*) FROM bad_prices)                                        AS c2_inconsistent_prices,
    (SELECT expected_weeks || ' / ' || found_weeks FROM long_rest_check)     AS c3_long_rest_expected_found,
    (SELECT '2 / ' || found_weeks FROM sunday_shift_check)                   AS c4_sunday_shift_expected_found,
    (SELECT COUNT(*) FROM {{ ref('silver_billing_account_week') }}
      WHERE expected_revenue < 60 * n_billable_locations)                    AS c5_revenue_below_floor,
    (SELECT COUNT(*) FROM {{ ref('silver_planning_weeks') }} AS pw
      INNER JOIN {{ ref('bronze_locations') }} AS l ON l.location_id = pw.location_id
      WHERE l.is_archived)                                                   AS c6_planning_on_archived

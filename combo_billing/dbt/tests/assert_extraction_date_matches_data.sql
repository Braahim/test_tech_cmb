-- La variable extraction_date doit correspondre à la dernière modification présente dans les données.

WITH last_update AS (
    SELECT MAX(updated_at)::DATE AS max_updated_date
    FROM (
        SELECT updated_at FROM {{ ref('bronze_shifts') }}
        UNION ALL
        SELECT updated_at FROM {{ ref('bronze_rests') }}
    )
)

SELECT max_updated_date
FROM last_update
WHERE max_updated_date <> '{{ var("extraction_date") }}'::DATE

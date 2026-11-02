-- SILVER.WEEKS : une ligne par semaine (lundi 00:00 UTC, fin exclue), bornée par les données, jamais par CURRENT_DATE.
-- WEEK_STATUS est calculé par rapport à la date d'extraction (var extraction_date).

{{ config(alias='WEEKS') }}

-- 1. Débuts de toutes les planifications (shifts + repos)
WITH planning_starts AS (
    SELECT starts_at FROM {{ ref('bronze_shifts') }}
    UNION ALL
    SELECT starts_at FROM {{ ref('bronze_rests') }}
),

-- 2. Bornes : lundi de la première et de la dernière planification (DAYOFWEEKISO : indépendant de WEEK_START)
bounds AS (
    SELECT
        MIN(starts_at)::DATE                                            AS first_planning_date,
        DATEADD('day', 1 - DAYOFWEEKISO(MIN(starts_at)), MIN(starts_at)::DATE) AS first_week_start,
        DATEADD('day', 1 - DAYOFWEEKISO(MAX(starts_at)), MAX(starts_at)::DATE) AS last_week_start
    FROM planning_starts
),

-- 3. Une ligne par semaine entre les bornes
spine AS (
    SELECT
        DATEADD('week', ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1, b.first_week_start) AS week_start,
        b.first_planning_date,
        b.last_week_start
    FROM TABLE(GENERATOR(ROWCOUNT => 1000))
    CROSS JOIN bounds AS b
)

-- 4. Statut de chaque semaine par rapport aux bornes des données et à la date d'extraction
SELECT
    week_start,
    DATEADD('day', 7, week_start) AS week_end,
    CASE
        WHEN week_start < first_planning_date                                   THEN 'partial_start'
        WHEN DATEADD('day', 7, week_start) <= '{{ var("extraction_date") }}'::DATE THEN 'complete'
        WHEN week_start <= '{{ var("extraction_date") }}'::DATE                 THEN 'in_progress'
        ELSE 'provisional'
    END AS week_status
FROM spine
WHERE week_start <= last_week_start

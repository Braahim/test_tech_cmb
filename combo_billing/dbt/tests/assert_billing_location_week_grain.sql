-- Grain de BILLING_LOCATION_WEEK : une seule ligne par établissement et par semaine.

SELECT location_id, week_start
FROM {{ ref('silver_billing_location_week') }}
GROUP BY location_id, week_start
HAVING COUNT(*) > 1

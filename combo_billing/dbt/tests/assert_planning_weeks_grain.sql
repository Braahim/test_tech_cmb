-- Grain de PLANNING_WEEKS : une seule ligne par contrat et par semaine.

SELECT user_contract_id, week_start
FROM {{ ref('silver_planning_weeks') }}
GROUP BY user_contract_id, week_start
HAVING COUNT(*) > 1

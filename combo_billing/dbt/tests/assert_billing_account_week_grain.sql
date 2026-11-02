-- Grain de BILLING_ACCOUNT_WEEK : une seule ligne par compte et par semaine.

SELECT account_id, week_start
FROM {{ ref('silver_billing_account_week') }}
GROUP BY account_id, week_start
HAVING COUNT(*) > 1

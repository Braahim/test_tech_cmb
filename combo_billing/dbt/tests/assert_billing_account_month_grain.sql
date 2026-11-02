-- Grain de BILLING_ACCOUNT_MONTH : une seule ligne par compte et par mois.

SELECT account_id, billing_month
FROM {{ ref('silver_billing_account_month') }}
GROUP BY account_id, billing_month
HAVING COUNT(*) > 1

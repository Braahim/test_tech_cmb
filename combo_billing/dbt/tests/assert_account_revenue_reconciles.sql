-- Le revenu par compte doit être exactement la somme des établissements (rien perdu, rien dupliqué).

WITH by_account AS (
    SELECT SUM(expected_revenue) AS total FROM {{ ref('silver_billing_account_week') }}
),

by_location AS (
    SELECT SUM(location_price) AS total FROM {{ ref('silver_billing_location_week') }}
)

SELECT a.total AS account_total, l.total AS location_total
FROM by_account AS a
CROSS JOIN by_location AS l
WHERE a.total <> l.total

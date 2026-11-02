-- GOLD.BILLING_ACCOUNT_WEEK : contrat exposé, une ligne par compte et par semaine (Q1 + Q2).
-- Les consommateurs se connectent ici, jamais à SILVER. Filtrer WEEK_STATUS = 'complete' pour facturer.

{{ config(alias='BILLING_ACCOUNT_WEEK') }}

SELECT
    b.account_id::VARCHAR                   AS account_id,
    a.account_name::VARCHAR                 AS account_name,
    a.country::VARCHAR                      AS country,
    b.week_start::DATE                      AS week_start,
    b.week_status::VARCHAR                  AS week_status,
    b.n_billable_locations::NUMBER(10, 0)   AS n_billable_locations,
    b.n_billable_employees::NUMBER(10, 0)   AS n_billable_employees,
    b.expected_revenue::NUMBER(12, 2)       AS expected_revenue,
    b.n_unassigned_contracts::NUMBER(10, 0) AS n_unassigned_contracts
FROM {{ ref('silver_billing_account_week') }} AS b
LEFT JOIN {{ ref('bronze_accounts') }} AS a
    ON a.account_id = b.account_id

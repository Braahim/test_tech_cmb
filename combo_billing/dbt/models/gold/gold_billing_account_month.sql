-- GOLD.BILLING_ACCOUNT_MONTH : contrat exposé, facture mensuelle simulée par compte.
-- Filtrer MONTH_STATUS = 'complete' : un mois incomplet ne doit pas être facturé.

{{ config(alias='BILLING_ACCOUNT_MONTH') }}

SELECT
    b.account_id::VARCHAR                       AS account_id,
    a.account_name::VARCHAR                     AS account_name,
    b.billing_month::DATE                       AS billing_month,
    b.month_status::VARCHAR                     AS month_status,
    b.n_weeks_billed::NUMBER(2, 0)              AS n_weeks_billed,
    b.n_weeks_in_month::NUMBER(2, 0)            AS n_weeks_in_month,
    b.avg_billable_locations::NUMBER(10, 1)     AS avg_billable_locations,
    b.avg_billable_employees::NUMBER(10, 1)     AS avg_billable_employees,
    b.monthly_invoice::NUMBER(12, 2)            AS monthly_invoice,
    b.avg_unassigned_contracts::NUMBER(10, 1)   AS avg_unassigned_contracts
FROM {{ ref('silver_billing_account_month') }} AS b
LEFT JOIN {{ ref('bronze_accounts') }} AS a
    ON a.account_id = b.account_id

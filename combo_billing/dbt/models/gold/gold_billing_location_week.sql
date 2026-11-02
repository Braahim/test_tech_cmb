-- GOLD.BILLING_LOCATION_WEEK : contrat exposé, une ligne par établissement et par semaine.
-- Détail de la facture : explique le montant d'un compte établissement par établissement.

{{ config(alias='BILLING_LOCATION_WEEK') }}

SELECT
    b.location_id::VARCHAR                  AS location_id,
    l.location_name::VARCHAR                AS location_name,
    b.account_id::VARCHAR                   AS account_id,
    b.week_start::DATE                      AS week_start,
    b.week_status::VARCHAR                  AS week_status,
    b.n_billable_employees::NUMBER(10, 0)   AS n_billable_employees,
    b.location_size::VARCHAR                AS location_size,
    b.location_price::NUMBER(12, 2)         AS location_price
FROM {{ ref('silver_billing_location_week') }} AS b
LEFT JOIN {{ ref('bronze_locations') }} AS l
    ON l.location_id = b.location_id

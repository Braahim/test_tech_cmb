-- BRONZE.MEMBERSHIPS : personnes rattachées à un compte, typées 1 pour 1 depuis STG_MEMBERSHIPS
-- Noms, adresses et preferences non repris (inutiles à la facturation, données personnelles).

{{ config(alias='MEMBERSHIPS') }}

SELECT
    TRIM(id)                                AS membership_id,
    TRIM(user_id)                           AS user_id,
    TRIM(account_id)                        AS account_id,
    TRIM(role)                              AS role,
    TRY_TO_BOOLEAN(TRIM(active))              AS is_active,
    {{ to_utc_timestamp('created_at') }}    AS created_at,
    {{ to_utc_timestamp('updated_at') }}    AS updated_at,
    _source_file,
    _source_row,
    CONVERT_TIMEZONE('UTC', _loaded_at)::TIMESTAMP_NTZ AS _ingestion_timestamp
FROM {{ source('stage', 'STG_MEMBERSHIPS') }}

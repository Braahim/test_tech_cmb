-- BRONZE.RESTS : repos et absences planifiés, typés 1 pour 1 depuis STG_RESTS

{{ config(alias='RESTS') }}

SELECT
    TRIM(id)                                AS rest_id,
    TRIM(user_contract_id)                  AS user_contract_id,
    TRIM(account_id)                        AS account_id,
    TRIM(rest_type)                         AS rest_type,
    {{ to_utc_timestamp('starts_at') }}     AS starts_at,
    {{ to_utc_timestamp('ends_at') }}       AS ends_at,
    {{ to_utc_timestamp('created_at') }}    AS created_at,
    {{ to_utc_timestamp('updated_at') }}    AS updated_at,
    _source_file,
    _source_row,
    CONVERT_TIMEZONE('UTC', _loaded_at)::TIMESTAMP_NTZ AS _ingestion_timestamp
FROM {{ source('stage', 'STG_RESTS') }}

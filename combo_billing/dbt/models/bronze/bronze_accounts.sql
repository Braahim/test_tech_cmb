-- BRONZE.ACCOUNTS : comptes clients, typés 1 pour 1 depuis STG_ACCOUNTS

{{ config(alias='ACCOUNTS') }}

SELECT
    TRIM(id)                                AS account_id,
    TRIM(name)                              AS account_name,
    TRIM(country)                           AS country,
    TRIM(time_zone)                         AS time_zone,
    {{ to_utc_timestamp('created_at') }}    AS created_at,
    {{ to_utc_timestamp('updated_at') }}    AS updated_at,
    _source_file,
    _source_row,
    CONVERT_TIMEZONE('UTC', _loaded_at)::TIMESTAMP_NTZ AS _ingestion_timestamp
FROM {{ source('stage', 'STG_ACCOUNTS') }}

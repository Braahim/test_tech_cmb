-- BRONZE.LOCATIONS : établissements, typés 1 pour 1 depuis STG_LOCATIONS

{{ config(alias='LOCATIONS') }}

SELECT
    TRIM(id)                                AS location_id,
    TRIM(account_id)                        AS account_id,
    TRIM(name)                              AS location_name,
    TRY_TO_BOOLEAN(TRIM(archived))            AS is_archived,
    {{ to_utc_timestamp('created_at') }}    AS created_at,
    {{ to_utc_timestamp('updated_at') }}    AS updated_at,
    _source_file,
    _source_row,
    CONVERT_TIMEZONE('UTC', _loaded_at)::TIMESTAMP_NTZ AS _ingestion_timestamp
FROM {{ source('stage', 'STG_LOCATIONS') }}

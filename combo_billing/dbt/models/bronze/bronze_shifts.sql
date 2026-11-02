-- BRONZE.SHIFTS : créneaux de travail planifiés, typés 1 pour 1 depuis STG_SHIFTS
-- Seuls les horaires planifiés sont repris : la facturation porte sur le planifié, pas le réalisé.

{{ config(alias='SHIFTS') }}

SELECT
    TRIM(id)                                AS shift_id,
    TRIM(user_contract_id)                  AS user_contract_id,
    TRIM(account_id)                        AS account_id,
    {{ to_utc_timestamp('starts_at') }}     AS starts_at,
    {{ to_utc_timestamp('ends_at') }}       AS ends_at,
    TRIM(planification_type)                AS planification_type,
    TRY_TO_BOOLEAN(TRIM(did_not_show))        AS did_not_show,
    {{ to_utc_timestamp('created_at') }}    AS created_at,
    {{ to_utc_timestamp('updated_at') }}    AS updated_at,
    _source_file,
    _source_row,
    CONVERT_TIMEZONE('UTC', _loaded_at)::TIMESTAMP_NTZ AS _ingestion_timestamp
FROM {{ source('stage', 'STG_SHIFTS') }}

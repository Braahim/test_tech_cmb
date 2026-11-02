-- BRONZE.USER_CONTRACTS : contrats (personne ↔ établissement), typés 1 pour 1 depuis STG_USER_CONTRACTS
-- contract_time : formats ' 39.99 ', '35h', '35,0' ramenés à un nombre d'heures.
-- Noms et adresses non repris (données personnelles, déjà portées par MEMBERSHIPS).

{{ config(alias='USER_CONTRACTS') }}

SELECT
    TRIM(id)                                        AS user_contract_id,
    TRIM(membership_id)                             AS membership_id,
    TRIM(location_id)                               AS location_id,
    TRIM(account_id)                                AS account_id,
    TRIM(original_contract_id)                      AS original_contract_id,
    TRIM(type)                                      AS contract_kind,
    TRIM(contract_type)                             AS contract_type,
    TRY_TO_DECIMAL(
        REPLACE(REPLACE(LOWER(TRIM(contract_time)), 'h', ''), ',', '.'),
        6, 2
    )                                               AS contract_hours_per_week,
    -- 2 formats ('2024-03-18' et '18/03/2024') : en AUTO, '05/03/2024' serait lu le 3 mai
    COALESCE(TRY_TO_DATE(TRIM(contract_start), 'YYYY-MM-DD'),
             TRY_TO_DATE(TRIM(contract_start), 'DD/MM/YYYY'))  AS contract_start,
    COALESCE(TRY_TO_DATE(TRIM(contract_end), 'YYYY-MM-DD'),
             TRY_TO_DATE(TRIM(contract_end), 'DD/MM/YYYY'))    AS contract_end,
    TRY_TO_BOOLEAN(TRIM(virtual))                     AS is_virtual,
    TRY_TO_BOOLEAN(TRIM(daily_worker))                AS is_daily_worker,
    {{ to_utc_timestamp('created_at') }}            AS created_at,
    {{ to_utc_timestamp('updated_at') }}            AS updated_at,
    _source_file,
    _source_row,
    CONVERT_TIMEZONE('UTC', _loaded_at)::TIMESTAMP_NTZ AS _ingestion_timestamp
FROM {{ source('stage', 'STG_USER_CONTRACTS') }}

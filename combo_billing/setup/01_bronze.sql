-- COMBO_BILLING : setup de la couche BRONZE (hors dbt)
-- Base, schéma, stage source, chargement brut des CSV (STG_*, tout en VARCHAR).
-- Rejouable : IF NOT EXISTS, et COPY INTO ignore les fichiers déjà chargés.

-- 1. Base et schéma (SILVER et GOLD sont créés par dbt)
CREATE DATABASE IF NOT EXISTS combo_billing;
CREATE SCHEMA IF NOT EXISTS combo_billing.bronze;

-- 2. Stage source : copie des CSV fournis
CREATE STAGE IF NOT EXISTS combo_billing.bronze.src_files
    DIRECTORY = (ENABLE = TRUE);

COPY FILES INTO @combo_billing.bronze.src_files
    FROM @test_tech.docs.data
    PATTERN = '.*[.]csv';

ALTER STAGE combo_billing.bronze.src_files REFRESH;
LIST @combo_billing.bronze.src_files;

-- 3. Format CSV (pas de TRIM_SPACE : les espaces sont des anomalies traitées en BRONZE.<TABLE>)
CREATE FILE FORMAT IF NOT EXISTS combo_billing.bronze.ff_csv
    TYPE = CSV
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    ESCAPE_UNENCLOSED_FIELD = NONE
    EMPTY_FIELD_AS_NULL = TRUE
    NULL_IF = ('');

-- 4. Tables STG_ : colonnes dans l'ordre de l'en-tête CSV + 3 colonnes de traçabilité

CREATE TABLE IF NOT EXISTS combo_billing.bronze.stg_accounts (
    id VARCHAR, name VARCHAR, created_at VARCHAR, updated_at VARCHAR, time_zone VARCHAR,
    default_language VARCHAR, city VARCHAR, street VARCHAR, zip VARCHAR,
    collective_agreement_id VARCHAR, cheat_sheet_hour_cut VARCHAR, social_tax VARCHAR,
    paid_breaks VARCHAR, show_real_and_planned_hours_on_planning VARCHAR, preferences VARCHAR,
    blocked VARCHAR, payroll_software_id VARCHAR, partner_id VARCHAR, country VARCHAR,
    _source_file VARCHAR, _source_row NUMBER, _loaded_at TIMESTAMP_LTZ
);
COPY INTO combo_billing.bronze.stg_accounts
FROM (
    SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,
           METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, CURRENT_TIMESTAMP()
    FROM @combo_billing.bronze.src_files/accounts.csv
)
FILE_FORMAT = (FORMAT_NAME = 'combo_billing.bronze.ff_csv');

CREATE TABLE IF NOT EXISTS combo_billing.bronze.stg_locations (
    id VARCHAR, name VARCHAR, account_id VARCHAR, created_at VARCHAR, updated_at VARCHAR,
    address VARCHAR, preferences VARCHAR, city VARCHAR, zipcode VARCHAR,
    collective_agreement_id VARCHAR, country VARCHAR, partner_id VARCHAR, archived VARCHAR,
    default_break_duration VARCHAR, payroll_software_identifier VARCHAR,
    enable_public_holiday_configuration VARCHAR, public_holiday_overtime_rate VARCHAR,
    public_holiday_paid_by_default VARCHAR, location_type VARCHAR,
    minimum_shift_duration_for_automatic_breaks_in_hours VARCHAR,
    _source_file VARCHAR, _source_row NUMBER, _loaded_at TIMESTAMP_LTZ
);
COPY INTO combo_billing.bronze.stg_locations
FROM (
    SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,
           METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, CURRENT_TIMESTAMP()
    FROM @combo_billing.bronze.src_files/locations.csv
)
FILE_FORMAT = (FORMAT_NAME = 'combo_billing.bronze.ff_csv');

CREATE TABLE IF NOT EXISTS combo_billing.bronze.stg_memberships (
    id VARCHAR, user_id VARCHAR, account_id VARCHAR, active VARCHAR, role VARCHAR,
    created_at VARCHAR, updated_at VARCHAR, sort_index VARCHAR, preferences VARCHAR,
    onboarded VARCHAR, can_manage_published_planning VARCHAR, can_invalidate_shift VARCHAR,
    can_remove_employee VARCHAR, can_set_custom_rest_value VARCHAR, lastname VARCHAR,
    street_address VARCHAR, enhanced_medical_examination VARCHAR, firstname VARCHAR,
    _source_file VARCHAR, _source_row NUMBER, _loaded_at TIMESTAMP_LTZ
);
COPY INTO combo_billing.bronze.stg_memberships
FROM (
    SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,
           METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, CURRENT_TIMESTAMP()
    FROM @combo_billing.bronze.src_files/memberships.csv
)
FILE_FORMAT = (FORMAT_NAME = 'combo_billing.bronze.ff_csv');

CREATE TABLE IF NOT EXISTS combo_billing.bronze.stg_user_contracts (
    id VARCHAR, created_at VARCHAR, updated_at VARCHAR, location_id VARCHAR,
    contract_end VARCHAR, contract_time VARCHAR, contract_start VARCHAR,
    contract_end_trial VARCHAR, contract_type VARCHAR, lastname VARCHAR, firstname VARCHAR,
    street_address VARCHAR, do_not_show_in_register VARCHAR, contract_end_reason VARCHAR,
    team_id VARCHAR, invitation_sent_at VARCHAR, invitation_accepted_at VARCHAR,
    membership_id VARCHAR, daily_worker VARCHAR, working_days_in_week VARCHAR,
    partner_id VARCHAR, birth_department_code VARCHAR, start_time VARCHAR,
    account_id VARCHAR, original_contract_id VARCHAR, type VARCHAR, virtual VARCHAR,
    _source_file VARCHAR, _source_row NUMBER, _loaded_at TIMESTAMP_LTZ
);
COPY INTO combo_billing.bronze.stg_user_contracts
FROM (
    SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,
           $21,$22,$23,$24,$25,$26,$27,
           METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, CURRENT_TIMESTAMP()
    FROM @combo_billing.bronze.src_files/user_contracts.csv
)
FILE_FORMAT = (FORMAT_NAME = 'combo_billing.bronze.ff_csv');

CREATE TABLE IF NOT EXISTS combo_billing.bronze.stg_shifts (
    id VARCHAR, user_contract_id VARCHAR, weeklyschedule_id VARCHAR, label_id VARCHAR,
    breakduration VARCHAR, starts_at VARCHAR, ends_at VARCHAR, real_breakduration VARCHAR,
    real_starts_at VARCHAR, real_ends_at VARCHAR, did_not_show VARCHAR, validated_at VARCHAR,
    validator_id VARCHAR, planned_hours_last_edited_at VARCHAR,
    planned_hours_last_edited_by_id VARCHAR, created_at VARCHAR, updated_at VARCHAR,
    locked_at VARCHAR, partner_id VARCHAR, account_id VARCHAR, planification_type VARCHAR,
    _source_file VARCHAR, _source_row NUMBER, _loaded_at TIMESTAMP_LTZ
);
COPY INTO combo_billing.bronze.stg_shifts
FROM (
    SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,
           METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, CURRENT_TIMESTAMP()
    FROM @combo_billing.bronze.src_files/shifts.csv
)
FILE_FORMAT = (FORMAT_NAME = 'combo_billing.bronze.ff_csv');

CREATE TABLE IF NOT EXISTS combo_billing.bronze.stg_rests (
    id VARCHAR, user_contract_id VARCHAR, timeoff_id VARCHAR, original_shift_id VARCHAR,
    rest_type VARCHAR, starts_at VARCHAR, ends_at VARCHAR, created_at VARCHAR,
    updated_at VARCHAR, partner_id VARCHAR, custom_value VARCHAR, account_id VARCHAR,
    _source_file VARCHAR, _source_row NUMBER, _loaded_at TIMESTAMP_LTZ
);
COPY INTO combo_billing.bronze.stg_rests
FROM (
    SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,
           METADATA$FILENAME, METADATA$FILE_ROW_NUMBER, CURRENT_TIMESTAMP()
    FROM @combo_billing.bronze.src_files/rests.csv
)
FILE_FORMAT = (FORMAT_NAME = 'combo_billing.bronze.ff_csv');

-- 5. Contrôle : attendu 30 | 167 | 7 711 | 3 857 | 484 086 | 192 590, avec n_ids = n_rows
SELECT 'stg_accounts' AS table_name, COUNT(*) AS n_rows, COUNT(DISTINCT id) AS n_ids FROM combo_billing.bronze.stg_accounts
UNION ALL SELECT 'stg_locations',      COUNT(*), COUNT(DISTINCT id) FROM combo_billing.bronze.stg_locations
UNION ALL SELECT 'stg_memberships',    COUNT(*), COUNT(DISTINCT id) FROM combo_billing.bronze.stg_memberships
UNION ALL SELECT 'stg_user_contracts', COUNT(*), COUNT(DISTINCT id) FROM combo_billing.bronze.stg_user_contracts
UNION ALL SELECT 'stg_shifts',         COUNT(*), COUNT(DISTINCT id) FROM combo_billing.bronze.stg_shifts
UNION ALL SELECT 'stg_rests',          COUNT(*), COUNT(DISTINCT id) FROM combo_billing.bronze.stg_rests
ORDER BY n_rows;

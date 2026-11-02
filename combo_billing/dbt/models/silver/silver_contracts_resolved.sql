-- SILVER.CONTRACTS_RESOLVED : contrats du fichier + contrats d'origine absents, reconstruits depuis leurs avenants
-- (le planning pointe vers l'original, jamais vers l'avenant).

{{ config(alias='CONTRACTS_RESOLVED') }}

-- 1. Contrats présents dans l'extrait
WITH contracts AS (
    SELECT
        user_contract_id,
        membership_id,
        location_id,
        account_id,
        contract_kind,
        original_contract_id
    FROM {{ ref('bronze_user_contracts') }}
),

-- 2. Contrats d'origine absents : reconstruits depuis leurs avenants (1 ligne par original)
rebuilt_from_amendments AS (
    SELECT
        amd.original_contract_id    AS user_contract_id,
        ANY_VALUE(amd.membership_id) AS membership_id,
        ANY_VALUE(amd.location_id)   AS location_id,
        ANY_VALUE(amd.account_id)    AS account_id,
        COUNT(*)                     AS n_amendments
    FROM contracts AS amd
    -- avenant dont l'original n'existe pas dans l'extrait
    LEFT JOIN contracts AS original
        ON original.user_contract_id = amd.original_contract_id
    WHERE amd.contract_kind = 'Amendment'
      AND amd.original_contract_id IS NOT NULL
      AND original.user_contract_id IS NULL
    GROUP BY amd.original_contract_id
)

-- 3. Union : contrats du fichier + contrats reconstruits
SELECT
    user_contract_id,
    membership_id,
    location_id,
    account_id,
    contract_kind,
    'file'          AS resolution_source,
    NULL::NUMBER    AS n_amendments
FROM contracts

UNION ALL

SELECT
    user_contract_id,
    membership_id,
    location_id,
    account_id,
    'UserContract'  AS contract_kind,
    'amendment'     AS resolution_source,
    n_amendments
FROM rebuilt_from_amendments

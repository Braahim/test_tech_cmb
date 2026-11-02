-- Les avenants d'un même contrat doivent pointer vers la même personne et le même établissement.

SELECT
    original_contract_id,
    COUNT(DISTINCT membership_id) AS n_memberships,
    COUNT(DISTINCT location_id)   AS n_locations
FROM {{ ref('bronze_user_contracts') }}
WHERE contract_kind = 'Amendment'
  AND original_contract_id IS NOT NULL
GROUP BY original_contract_id
HAVING COUNT(DISTINCT membership_id) > 1
    OR COUNT(DISTINCT location_id) > 1

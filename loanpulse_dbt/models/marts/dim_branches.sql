-- Branch dimension: one row per branch.
-- Joins to the facts on branch_id.

SELECT
    branch_id,
    branch_name,
    district,
    state,
    branch_name || ' (' || district || ')' AS branch_label,
    opened_date
FROM {{ ref('stg_branches') }}

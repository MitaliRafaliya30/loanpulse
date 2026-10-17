-- Every key must have exactly ONE current version (dbt_valid_to IS NULL),
-- and every key in staging must appear in its snapshot.
-- A test passes when this query returns zero rows.

WITH current_versions AS (
    SELECT 'snap_branches' AS snapshot_name, branch_id AS key_value
    FROM {{ ref('snap_branches') }}
    WHERE dbt_valid_to IS NULL

    UNION ALL

    SELECT 'snap_borrower_groups', group_id
    FROM {{ ref('snap_borrower_groups') }}
    WHERE dbt_valid_to IS NULL

    UNION ALL

    SELECT 'snap_customers', customer_id
    FROM {{ ref('snap_customers') }}
    WHERE dbt_valid_to IS NULL
),

duplicated AS (
    SELECT
        snapshot_name,
        key_value,
        COUNT(*) AS current_rows
    FROM current_versions
    GROUP BY
        snapshot_name,
        key_value
    HAVING COUNT(*) > 1
),

missing AS (
    SELECT 'snap_branches' AS snapshot_name, s.branch_id AS key_value, 0 AS current_rows
    FROM {{ ref('stg_branches') }} s
    LEFT JOIN current_versions c
        ON c.snapshot_name = 'snap_branches' AND c.key_value = s.branch_id
    WHERE c.key_value IS NULL

    UNION ALL

    SELECT 'snap_borrower_groups', s.group_id, 0
    FROM {{ ref('stg_borrower_groups') }} s
    LEFT JOIN current_versions c
        ON c.snapshot_name = 'snap_borrower_groups' AND c.key_value = s.group_id
    WHERE c.key_value IS NULL

    UNION ALL

    SELECT 'snap_customers', s.customer_id, 0
    FROM {{ ref('stg_customers_no_pii') }} s
    LEFT JOIN current_versions c
        ON c.snapshot_name = 'snap_customers' AND c.key_value = s.customer_id
    WHERE c.key_value IS NULL
)

SELECT * FROM duplicated
UNION ALL
SELECT * FROM missing

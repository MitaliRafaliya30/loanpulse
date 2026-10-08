-- Staging must contain exactly one row for every distinct payment in RAW.
-- If this fails, deduplication either lost payments or kept duplicates.

WITH raw_side AS (
    SELECT
        COUNT(DISTINCT collection_id) AS raw_unique_payments
    FROM {{ source('raw', 'collections') }}
),

staging_side AS (
    SELECT
        COUNT(*) AS staging_rows
    FROM {{ ref('stg_collections') }}
)

SELECT *
FROM raw_side
CROSS JOIN staging_side
WHERE raw_unique_payments != staging_rows
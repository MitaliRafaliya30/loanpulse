-- Source systems sometimes send the same payment twice.
-- We keep only the first copy of each collection_id.

WITH source AS (
    SELECT *
    FROM {{ source('raw', 'collections') }}
),

numbered AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY collection_id
            ORDER BY _loaded_at, _source_file
        ) AS copy_number
    FROM source
)

SELECT
    collection_id,
    loan_id,
    payment_date,
    posted_date,
    amount,
    payment_mode,
    field_officer_id,
    _source_file
FROM numbered
WHERE copy_number = 1
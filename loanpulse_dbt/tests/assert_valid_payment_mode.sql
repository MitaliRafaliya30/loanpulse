-- Only CASH and UPI are allowed.

SELECT
    collection_id,
    payment_mode
FROM {{ ref('stg_collections') }}
WHERE payment_mode NOT IN ('CASH', 'UPI')
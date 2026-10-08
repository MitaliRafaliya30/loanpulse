-- Every payment must belong to a loan that exists.
-- A test passes when this query returns zero rows.

SELECT
    c.collection_id,
    c.loan_id
FROM {{ ref('stg_collections') }} c
LEFT JOIN {{ ref('stg_loans') }} l
    ON c.loan_id = l.loan_id
WHERE l.loan_id IS NULL
-- A corrected payment must show the values of the correction, not the original.
-- Rows from a collections_corrections file always beat the original file,
-- so staging must match them exactly.
-- A test passes when this query returns zero rows.
-- (With no correction files loaded, it returns zero rows too.)

SELECT
    r.collection_id,
    r.amount AS correction_amount,
    s.amount AS staged_amount,
    r.payment_mode AS correction_mode,
    s.payment_mode AS staged_mode,
    r.field_officer_id AS correction_officer,
    s.field_officer_id AS staged_officer
FROM {{ source('raw', 'collections') }} r

LEFT JOIN {{ ref('stg_collections') }} s
    ON r.collection_id = s.collection_id

WHERE r._source_file LIKE '%collections_corrections%'
  AND (
        s.collection_id IS NULL
        OR s.amount != r.amount
        OR s.payment_mode != r.payment_mode
        OR s.field_officer_id != r.field_officer_id
        OR NOT s.is_corrected
  )

-- One row per payment: the LATEST version of each collection_id.
--
-- RAW keeps every version that ever arrived (append-only, good for audit).
-- A payment can arrive more than once:
--   - exact duplicates sent by the source system, and
--   - corrections: the same collection_id sent again later in a new file.
-- The source has no updated_at column, so the version date is the landing
-- folder date in the file path (date=YYYY-MM-DD). The newest version wins.
--
-- Incremental MERGE: only payments that received new RAW rows are recomputed,
-- using ALL their versions. This stays correct even if an older file is
-- loaded after a newer one (out-of-order arrival).

{{
    config(
        materialized = 'incremental',
        unique_key = 'collection_id',
        incremental_strategy = 'merge'
    )
}}

WITH raw_rows AS (
    SELECT
        *,
        COALESCE(
            TRY_TO_DATE(
                REGEXP_SUBSTR(_source_file, 'date=([0-9]{4}-[0-9]{2}-[0-9]{2})', 1, 1, 'e', 1)
            ),
            posted_date
        ) AS version_date
    FROM {{ source('raw', 'collections') }}
),

{% if is_incremental() %}
changed_payments AS (
    -- Payments that received new rows since the last run
    SELECT DISTINCT collection_id
    FROM raw_rows
    WHERE _loaded_at > (SELECT MAX(_loaded_at) FROM {{ this }})
),
{% endif %}

candidates AS (
    SELECT r.*
    FROM raw_rows r

    {% if is_incremental() %}
    JOIN changed_payments c
        ON r.collection_id = c.collection_id
    {% endif %}
),

versions AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY collection_id
            ORDER BY version_date DESC, _loaded_at DESC, _source_file DESC
        ) AS version_rank,

        -- More than one file means the payment was re-sent (a correction)
        MIN(_source_file) OVER (PARTITION BY collection_id)
            != MAX(_source_file) OVER (PARTITION BY collection_id) AS is_corrected
    FROM candidates
)

SELECT
    collection_id,
    loan_id,
    payment_date,
    posted_date,
    amount,
    payment_mode,
    field_officer_id,
    _source_file,
    _loaded_at,
    version_date AS record_version_date,
    is_corrected
FROM versions
WHERE version_rank = 1

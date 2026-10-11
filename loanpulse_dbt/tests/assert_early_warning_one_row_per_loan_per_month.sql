-- One loan, one month-end, one row.
-- Duplicates would bias the model.

SELECT
    snapshot_date,
    loan_id,
    COUNT(*) AS row_count
FROM {{ ref('fct_early_warning_features') }}
GROUP BY
    snapshot_date,
    loan_id
HAVING COUNT(*) > 1
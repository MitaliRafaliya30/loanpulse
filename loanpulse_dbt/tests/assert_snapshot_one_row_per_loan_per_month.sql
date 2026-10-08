-- The grain of the snapshot is one loan, one month-end.

SELECT
    snapshot_date,
    loan_id,
    COUNT(*) AS row_count
FROM {{ ref('fct_portfolio_month_end_snapshot') }}
GROUP BY
    snapshot_date,
    loan_id
HAVING COUNT(*) > 1
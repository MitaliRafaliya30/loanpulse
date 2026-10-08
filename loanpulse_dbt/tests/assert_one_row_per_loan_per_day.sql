-- The grain of fct_loan_daily_status is one loan, one day.

SELECT
    loan_id,
    status_date,
    COUNT(*) AS row_count
FROM {{ ref('fct_loan_daily_status') }}
GROUP BY
    loan_id,
    status_date
HAVING COUNT(*) > 1
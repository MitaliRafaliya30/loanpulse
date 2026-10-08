-- DPD and money values can never be negative.

SELECT
    loan_id,
    status_date,
    dpd,
    outstanding_principal,
    overdue_amount
FROM {{ ref('fct_loan_daily_status') }}
WHERE dpd < 0
   OR outstanding_principal < 0
   OR overdue_amount < 0
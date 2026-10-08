-- The write-off amount sent by the source system must match the
-- outstanding principal we calculated on the write-off date.

SELECT
    w.loan_id,
    w.writeoff_amount,
    f.outstanding_principal
FROM {{ ref('stg_loan_writeoffs') }} w
JOIN {{ ref('fct_loan_daily_status') }} f
    ON w.loan_id = f.loan_id
    AND w.writeoff_date = f.status_date
WHERE ABS(
    w.writeoff_amount - f.outstanding_principal
) > 1
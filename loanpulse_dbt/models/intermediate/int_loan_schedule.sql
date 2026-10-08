-- Adds a running total of how much should have been paid
-- by the end of each installment.
-- Example: installments of 2800 each give cumulative_due 2800, 5600, 8400 ...

SELECT
    loan_id,
    installment_number,
    due_date,
    principal_due,
    interest_due,
    total_due,
    SUM(total_due) OVER (
        PARTITION BY loan_id
        ORDER BY installment_number
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_due
FROM {{ ref('stg_repayment_schedule') }}
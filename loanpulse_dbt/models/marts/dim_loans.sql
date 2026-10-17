-- Loan dimension: one row per loan, with contract terms and lifecycle.
-- No customer PII here, only customer_id (join to dim_customers if needed).
-- loan_status is the current status as of the as_of_date.

SELECT
    l.loan_id,
    l.customer_id,
    lc.branch_id,
    l.product_type,
    l.principal_amount,
    l.interest_rate,
    l.tenure_months,
    l.disbursement_date,
    DATE_TRUNC('month', l.disbursement_date) AS vintage_month,
    lc.total_contract_due,
    lc.closure_date,
    lc.writeoff_date,

    CASE
        WHEN lc.writeoff_date IS NOT NULL THEN 'WRITTEN_OFF'
        WHEN lc.closure_date IS NOT NULL THEN 'CLOSED'
        ELSE 'ACTIVE'
    END AS loan_status

FROM {{ ref('stg_loans') }} l

JOIN {{ ref('int_loan_lifecycle') }} lc
    ON l.loan_id = lc.loan_id

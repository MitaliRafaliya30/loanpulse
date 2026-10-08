-- One row per loan with its key dates:
-- when it started, when it was fully repaid (closed),
-- when it was written off, and the last date we need to track it.

WITH loans AS (
    SELECT *
    FROM {{ ref('stg_loans') }}
),

customers AS (
    SELECT
        customer_id,
        branch_id
    FROM {{ ref('stg_customers') }}
),

contract_totals AS (
    -- Total amount the borrower must pay over the full loan
    SELECT
        loan_id,
        SUM(total_due) AS total_contract_due
    FROM {{ ref('int_loan_schedule') }}
    GROUP BY loan_id
),

running_payments AS (
    -- Running total of payments, in the order they were paid
    SELECT
        loan_id,
        payment_date,
        SUM(amount) OVER (
            PARTITION BY loan_id
            ORDER BY payment_date, collection_id
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_paid
    FROM {{ ref('stg_collections') }}
),

closures AS (
    -- First date on which everything was paid (1 rupee tolerance for rounding)
    SELECT
        p.loan_id,
        MIN(p.payment_date) AS closure_date
    FROM running_payments p
    JOIN contract_totals c
        ON p.loan_id = c.loan_id
    WHERE p.running_paid >= c.total_contract_due - 1
    GROUP BY p.loan_id
)

SELECT
    l.loan_id,
    l.customer_id,
    cu.branch_id,
    l.principal_amount,
    l.disbursement_date,
    ct.total_contract_due,
    cl.closure_date,
    w.writeoff_date,

    -- Stop tracking at the earliest of:
    -- closure, write-off, or today
    LEAST(
        COALESCE(cl.closure_date, '{{ var("as_of_date") }}'::date),
        COALESCE(w.writeoff_date, '{{ var("as_of_date") }}'::date),
        '{{ var("as_of_date") }}'::date
    ) AS last_status_date

FROM loans l
JOIN customers cu
    ON l.customer_id = cu.customer_id
JOIN contract_totals ct
    ON l.loan_id = ct.loan_id
LEFT JOIN closures cl
    ON l.loan_id = cl.loan_id
LEFT JOIN {{ ref('stg_loan_writeoffs') }} w
    ON l.loan_id = w.loan_id
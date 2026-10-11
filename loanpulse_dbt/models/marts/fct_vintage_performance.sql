-- Vintage analysis: groups loans by the month they were disbursed
-- and tracks how many became 30+ days late as they aged.
-- If newer vintages go bad faster, loan approval has become weaker.

WITH snapshot AS (
    SELECT *
    FROM {{ ref('fct_portfolio_month_end_snapshot') }}
),

loans AS (
    SELECT
        loan_id,
        principal_amount,
        DATE_TRUNC('month', disbursement_date) AS vintage_month
    FROM {{ ref('int_loan_lifecycle') }}
),

cohorts AS (
    -- Size of each vintage
    SELECT
        vintage_month,
        COUNT(*) AS loans_disbursed,
        SUM(principal_amount) AS amount_disbursed
    FROM loans
    GROUP BY vintage_month
),

performance AS (
    -- For each vintage and each month of age:
    -- how many loans were 30+ DPD
    SELECT
        l.vintage_month,
        DATEDIFF(
            month,
            l.vintage_month,
            s.snapshot_date
        ) AS months_on_book,
        COUNT_IF(s.dpd > 30) AS par30_loans,
        COUNT_IF(s.asset_class = 'NPA') AS npa_loans
    FROM snapshot s
    JOIN loans l
        ON s.loan_id = l.loan_id
    GROUP BY
        l.vintage_month,
        DATEDIFF(
            month,
            l.vintage_month,
            s.snapshot_date
        )
)

SELECT
    p.vintage_month,
    p.months_on_book,
    c.loans_disbursed,
    c.amount_disbursed,
    p.par30_loans,
    p.npa_loans,
    ROUND(
        100.0 * p.par30_loans / NULLIF(c.loans_disbursed, 0),
        2
    ) AS par30_loans_pct,
    ROUND(
        100.0 * p.npa_loans / NULLIF(c.loans_disbursed, 0),
        2
    ) AS npa_loans_pct
FROM performance p
JOIN cohorts c
    ON p.vintage_month = c.vintage_month
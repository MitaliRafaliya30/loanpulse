-- One row per branch per month with the key risk metrics.
-- Built from the frozen month-end snapshot, so it matches what was reported.

WITH snapshot AS (
    SELECT *
    FROM {{ ref('fct_portfolio_month_end_snapshot') }}
),

lifecycle AS (
    SELECT
        loan_id,
        branch_id,
        writeoff_date
    FROM {{ ref('int_loan_lifecycle') }}
),

portfolio AS (
    SELECT
        snapshot_date,
        branch_id,
        COUNT(*) AS active_loans,
        COUNT_IF(asset_class = 'NPA') AS npa_loans,
        SUM(outstanding_principal) AS total_outstanding,
        SUM(
            CASE
                WHEN asset_class = 'NPA'
                    THEN outstanding_principal
                ELSE 0
            END
        ) AS npa_outstanding,
        SUM(
            CASE
                WHEN dpd > 30
                    THEN outstanding_principal
                ELSE 0
            END
        ) AS par30_outstanding

    FROM snapshot

    GROUP BY
        snapshot_date,
        branch_id
),

dues AS (
    -- Installments that fell due in each month
    -- (not counting written-off loans)
    SELECT
        LAST_DAY(s.due_date) AS snapshot_date,
        l.branch_id,
        SUM(s.total_due) AS amount_due

    FROM {{ ref('int_loan_schedule') }} s

    JOIN lifecycle l
        ON s.loan_id = l.loan_id

    WHERE l.writeoff_date IS NULL
       OR s.due_date < l.writeoff_date

    GROUP BY
        LAST_DAY(s.due_date),
        l.branch_id
),

collected AS (
    -- Money counted in the month it was recorded in the books
    SELECT
        LAST_DAY(c.posted_date) AS snapshot_date,
        l.branch_id,
        SUM(c.amount) AS amount_collected

    FROM {{ ref('stg_collections') }} c

    JOIN lifecycle l
        ON c.loan_id = l.loan_id

    GROUP BY
        LAST_DAY(c.posted_date),
        l.branch_id
)

SELECT
    p.snapshot_date,
    p.branch_id,
    p.active_loans,
    p.npa_loans,
    p.total_outstanding,
    p.npa_outstanding,
    p.par30_outstanding,
    d.amount_due,
    COALESCE(c.amount_collected, 0) AS amount_collected,

    ROUND(
        100 * p.npa_outstanding
        / NULLIF(p.total_outstanding, 0),
        2
    ) AS gnpa_pct,

    ROUND(
        100 * p.par30_outstanding
        / NULLIF(p.total_outstanding, 0),
        2
    ) AS par30_pct,

    ROUND(
        100 * COALESCE(c.amount_collected, 0)
        / NULLIF(d.amount_due, 0),
        2
    ) AS collection_efficiency_pct

FROM portfolio p

LEFT JOIN dues d
    ON p.snapshot_date = d.snapshot_date
    AND p.branch_id = d.branch_id

LEFT JOIN collected c
    ON p.snapshot_date = c.snapshot_date
    AND p.branch_id = c.branch_id
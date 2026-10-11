-- Features and outcome for the early warning model.
-- One row per loan per month-end, for loans 0 to 30 days late.
--
-- No look-ahead (data leakage):
--   FEATURES come from the frozen month-end snapshot = what the bank knew that day.
--   OUTCOME comes from the daily status table = what actually happened later.

WITH snapshot AS (
    SELECT *
    FROM {{ ref('fct_portfolio_month_end_snapshot') }}
),

loan_groups AS (
    SELECT
        l.loan_id,
        c.group_id
    FROM {{ ref('stg_loans') }} l
    JOIN {{ ref('stg_customers') }} c
        ON l.customer_id = c.customer_id
),

history AS (
    -- How many of the last 6 month-ends (including this one) was the loan late?
    SELECT
        s.snapshot_date,
        s.loan_id,
        s.branch_id,
        s.dpd,
        s.asset_class,
        g.group_id,
        SUM(IFF(s.dpd > 0, 1, 0)) OVER (
            PARTITION BY s.loan_id
            ORDER BY s.snapshot_date
            ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
        ) AS late_months_6m
    FROM snapshot s
    JOIN loan_groups g
        ON s.loan_id = g.loan_id
),

group_status AS (
    -- JLG contagion: how many loans in the same group are late?
    SELECT
        snapshot_date,
        group_id,
        COUNT(*) AS group_loans,
        SUM(IFF(dpd > 0, 1, 0)) AS group_late_loans
    FROM history
    GROUP BY
        snapshot_date,
        group_id
),

future AS (
    -- Worst DPD in the 60 days AFTER the month-end
    SELECT
        h.snapshot_date,
        h.loan_id,
        MAX(d.dpd) AS max_dpd_next_60d
    FROM history h
    JOIN {{ ref('fct_loan_daily_status') }} d
        ON d.loan_id = h.loan_id
        AND d.status_date > h.snapshot_date
        AND d.status_date <= DATEADD(
            day,
            60,
            h.snapshot_date
        )
    GROUP BY
        h.snapshot_date,
        h.loan_id
)

SELECT
    h.snapshot_date,
    h.loan_id,
    h.branch_id,

    -- Features
    h.dpd AS dpd_now,
    h.late_months_6m,
    b.gnpa_pct AS branch_gnpa_pct,

    CASE
        WHEN gs.group_loans > 1
            -- Other members only, not this loan itself
            THEN (
                gs.group_late_loans - IFF(h.dpd > 0, 1, 0)
            ) / (gs.group_loans - 1)
        ELSE 0
    END AS group_late_share,

    -- Outcome (NULL when the 60 days are not over yet)
    CASE
        WHEN DATEADD(day, 60, h.snapshot_date)
            <= '{{ var("as_of_date") }}'::DATE
            THEN IFF(
                COALESCE(f.max_dpd_next_60d, 0) > 30,
                1,
                0
            )
    END AS went_30plus_next_60d

FROM history h

JOIN {{ ref('fct_branch_monthly_metrics') }} b
    ON b.snapshot_date = h.snapshot_date
    AND b.branch_id = h.branch_id

JOIN group_status gs
    ON gs.snapshot_date = h.snapshot_date
    AND gs.group_id = h.group_id

LEFT JOIN future f
    ON f.snapshot_date = h.snapshot_date
    AND f.loan_id = h.loan_id

WHERE h.dpd <= 30
    AND h.asset_class != 'NPA'
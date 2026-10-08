-- Month-end portfolio snapshot, as the bank KNEW it on the last day of the month.
--
-- Two rules make this audit-ready:
--   1. Only payments POSTED by the month-end date are counted (reporting cutoff).
--   2. Once a month is written, it is never rebuilt (frozen).
--      incremental = only new months are added
--      full_refresh = false = even "dbt run --full-refresh" cannot rebuild it

{{
    config(
        materialized = 'incremental',
        full_refresh = false
    )
}}

WITH month_ends AS (
    SELECT
        LAST_DAY(
            DATEADD(
                month,
                ROW_NUMBER() OVER (ORDER BY seq4()) - 1,
                '{{ var("spine_start_date") }}'::date
            )
        ) AS snapshot_date
    FROM TABLE(GENERATOR(ROWCOUNT => 60))
),

months_to_build AS (
    SELECT
        snapshot_date
    FROM month_ends
    WHERE snapshot_date <= '{{ var("as_of_date") }}'::date

    {% if is_incremental() %}
        -- Only months that are not in the table yet
        AND snapshot_date > (
            SELECT MAX(snapshot_date)
            FROM {{ this }}
        )
    {% endif %}
),

loans AS (
    SELECT *
    FROM {{ ref('int_loan_lifecycle') }}
),

loan_months AS (
    -- Loans that existed on the month-end date and were not written off
    SELECT
        m.snapshot_date,
        l.loan_id,
        l.branch_id,
        l.principal_amount,
        l.total_contract_due
    FROM months_to_build m
    JOIN loans l
        ON l.disbursement_date <= m.snapshot_date
        AND (
            l.writeoff_date IS NULL
            OR l.writeoff_date > m.snapshot_date
        )
),

reported_payments AS (
    -- Only payments the bank knew about on the snapshot date
    SELECT
        lm.snapshot_date,
        lm.loan_id,
        COALESCE(SUM(c.amount), 0) AS reported_paid
    FROM loan_months lm
    LEFT JOIN {{ ref('stg_collections') }} c
        ON c.loan_id = lm.loan_id
        AND c.payment_date <= lm.snapshot_date
        AND c.posted_date <= lm.snapshot_date
    GROUP BY
        lm.snapshot_date,
        lm.loan_id
),

vs_schedule AS (
    -- Same DPD logic as fct_loan_daily_status,
    -- using reported payments
    SELECT
        lm.snapshot_date,
        lm.loan_id,
        lm.branch_id,
        lm.principal_amount,
        lm.total_contract_due,
        rp.reported_paid,

        MIN(
            CASE
                WHEN s.cumulative_due > rp.reported_paid + 1
                    THEN s.due_date
            END
        ) AS oldest_unpaid_due_date,

        SUM(
            CASE
                WHEN s.cumulative_due <= rp.reported_paid + 1
                    THEN s.principal_due
                ELSE 0
            END
        ) AS principal_repaid,

        SUM(
            CASE
                WHEN s.due_date < lm.snapshot_date
                    THEN s.total_due
                ELSE 0
            END
        ) AS total_due_till_date

    FROM loan_months lm

    JOIN reported_payments rp
        ON lm.loan_id = rp.loan_id
        AND lm.snapshot_date = rp.snapshot_date

    JOIN {{ ref('int_loan_schedule') }} s
        ON lm.loan_id = s.loan_id

    GROUP BY
        lm.snapshot_date,
        lm.loan_id,
        lm.branch_id,
        lm.principal_amount,
        lm.total_contract_due,
        rp.reported_paid
),

with_dpd AS (
    SELECT
        *,
        principal_amount - principal_repaid AS outstanding_principal,

        GREATEST(
            total_due_till_date - reported_paid,
            0
        ) AS overdue_amount,

        CASE
            WHEN oldest_unpaid_due_date < snapshot_date
                THEN DATEDIFF(
                    day,
                    oldest_unpaid_due_date,
                    snapshot_date
                )
            ELSE 0
        END AS dpd

    FROM vs_schedule
),

daily_status AS (
    -- Used only for the NPA upgrade rule (needs day-by-day history)
    SELECT
        loan_id,
        status_date,
        asset_class
    FROM {{ ref('fct_loan_daily_status') }}
)

SELECT
    v.snapshot_date,
    v.loan_id,
    v.branch_id,
    v.outstanding_principal,
    v.overdue_amount,
    v.dpd,

    CASE
        WHEN v.dpd > 90 THEN 'NPA'

        -- RBI upgrade rule:
        -- an NPA loan with any overdue left stays NPA
        WHEN d.asset_class = 'NPA'
             AND v.dpd > 0
            THEN 'NPA'

        WHEN v.dpd = 0 THEN 'STANDARD'
        WHEN v.dpd <= 30 THEN 'SMA_0'
        WHEN v.dpd <= 60 THEN 'SMA_1'
        ELSE 'SMA_2'
    END AS asset_class,

    CURRENT_TIMESTAMP() AS snapshot_created_at

FROM with_dpd v

LEFT JOIN daily_status d
    ON v.loan_id = d.loan_id
    AND v.snapshot_date = d.status_date

-- Loans already fully repaid (as known on that date)
-- are not in the portfolio
WHERE v.reported_paid < v.total_contract_due - 1
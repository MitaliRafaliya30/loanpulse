-- One row per loan per day with DPD and RBI asset classification.
--
-- Core idea:
--   Compare "total paid so far" with the running total of installments.
--   The first installment whose cumulative_due is more than total paid
--   is the oldest unpaid installment. DPD is counted from its due date.

WITH daily AS (
    SELECT *
    FROM {{ ref('int_loan_daily_payments') }}
),

schedule AS (
    SELECT *
    FROM {{ ref('int_loan_schedule') }}
),

loan_info AS (
    SELECT
        loan_id,
        branch_id,
        principal_amount,
        writeoff_date
    FROM {{ ref('int_loan_lifecycle') }}
),

daily_vs_schedule AS (
    SELECT
        d.loan_id,
        d.status_date,
        d.cumulative_paid,

        -- Due date of the oldest installment not fully covered by payments
        MIN(
            CASE
                WHEN s.cumulative_due > d.cumulative_paid + 1
                    THEN s.due_date
            END
        ) AS oldest_unpaid_due_date,

        -- Principal of installments fully covered by payments
        SUM(
            CASE
                WHEN s.cumulative_due <= d.cumulative_paid + 1
                    THEN s.principal_due
                ELSE 0
            END
        ) AS principal_repaid,

        -- Everything that was due before today
        SUM(
            CASE
                WHEN s.due_date < d.status_date
                    THEN s.total_due
                ELSE 0
            END
        ) AS total_due_till_date

    FROM daily d

    JOIN schedule s
        ON d.loan_id = s.loan_id

    GROUP BY
        d.loan_id,
        d.status_date,
        d.cumulative_paid
),

with_dpd AS (
    SELECT
        x.loan_id,
        x.status_date,
        li.branch_id,
        li.writeoff_date,

        li.principal_amount - x.principal_repaid
            AS outstanding_principal,

        GREATEST(
            x.total_due_till_date - x.cumulative_paid,
            0
        ) AS overdue_amount,

        CASE
            WHEN x.oldest_unpaid_due_date < x.status_date
                THEN DATEDIFF(
                    day,
                    x.oldest_unpaid_due_date,
                    x.status_date
                )
            ELSE 0
        END AS dpd

    FROM daily_vs_schedule x

    JOIN loan_info li
        ON x.loan_id = li.loan_id
),

npa_tracking AS (
    -- For the RBI upgrade rule we need history:
    --   last_npa_date   = last day the loan was more than 90 DPD
    --   last_clear_date = last day the loan had no overdue at all

    SELECT
        *,

        MAX(
            CASE
                WHEN dpd > 90
                    THEN status_date
            END
        ) OVER (
            PARTITION BY loan_id
            ORDER BY status_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS last_npa_date,

        MAX(
            CASE
                WHEN dpd = 0
                    THEN status_date
            END
        ) OVER (
            PARTITION BY loan_id
            ORDER BY status_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS last_clear_date

    FROM with_dpd
)

SELECT
    status_date,
    loan_id,
    branch_id,
    outstanding_principal,
    overdue_amount,
    dpd,

    CASE
        WHEN dpd > 90 THEN 'NPA'

        -- RBI rule: once NPA, stays NPA until ALL overdue is cleared
        WHEN last_npa_date IS NOT NULL
             AND (
                 last_clear_date IS NULL
                 OR last_clear_date < last_npa_date
             )
            THEN 'NPA'

        WHEN dpd = 0 THEN 'STANDARD'
        WHEN dpd <= 30 THEN 'SMA_0'
        WHEN dpd <= 60 THEN 'SMA_1'
        ELSE 'SMA_2'
    END AS asset_class,

    COALESCE(
        status_date >= writeoff_date,
        FALSE
    ) AS is_written_off

FROM npa_tracking
-- One row per loan per day, with the total amount paid up to that day.

WITH date_spine AS (
    -- A simple calendar: one row per day starting from spine_start_date
    SELECT
        DATEADD(
            day,
            ROW_NUMBER() OVER (ORDER BY seq4()) - 1,
            '{{ var("spine_start_date") }}'::date
        ) AS calendar_date
    FROM TABLE(GENERATOR(ROWCOUNT => 1000))
),

loan_days AS (
    -- Every day from disbursement until the last tracked date
    SELECT
        l.loan_id,
        d.calendar_date AS status_date
    FROM {{ ref('int_loan_lifecycle') }} l
    JOIN date_spine d
        ON d.calendar_date BETWEEN l.disbursement_date
        AND l.last_status_date
),

payments_per_day AS (
    -- Uses payment_date (when the borrower actually paid),
    -- not posted_date (when it was recorded).
    -- This is what fixes late entries.
    SELECT
        loan_id,
        payment_date,
        SUM(amount) AS amount_paid
    FROM {{ ref('stg_collections') }}
    GROUP BY
        loan_id,
        payment_date
)

SELECT
    ld.loan_id,
    ld.status_date,
    COALESCE(p.amount_paid, 0) AS amount_paid_today,

    SUM(COALESCE(p.amount_paid, 0)) OVER (
        PARTITION BY ld.loan_id
        ORDER BY ld.status_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_paid

FROM loan_days ld

LEFT JOIN payments_per_day p
    ON ld.loan_id = p.loan_id
    AND ld.status_date = p.payment_date
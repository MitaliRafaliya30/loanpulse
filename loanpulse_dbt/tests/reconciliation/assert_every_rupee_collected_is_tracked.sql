-- For every loan, total money collected must equal the final
-- cumulative_paid in the daily table. No rupee lost, no rupee added.

WITH collected AS (
    SELECT
        loan_id,
        SUM(amount) AS total_collected
    FROM {{ ref('stg_collections') }}
    GROUP BY loan_id
),

tracked AS (
    SELECT
        loan_id,
        MAX(cumulative_paid) AS total_tracked
    FROM {{ ref('int_loan_daily_payments') }}
    GROUP BY loan_id
)

SELECT
    c.loan_id,
    c.total_collected,
    t.total_tracked
FROM collected c
LEFT JOIN tracked t
    ON c.loan_id = t.loan_id
WHERE t.total_tracked IS NULL
   OR ABS(c.total_collected - t.total_tracked) > 0.01
-- How loans moved between RBI categories from one month-end to the next.
-- Example row: from SMA_1 to SMA_2, 32 loans, 91% of last month's SMA_1 loans.
-- Loans that closed or were written off in the month are not included.

WITH snapshot AS (
    SELECT
        snapshot_date,
        loan_id,
        asset_class
    FROM {{ ref('fct_portfolio_month_end_snapshot') }}
)

SELECT
    cur.snapshot_date,
    prev.asset_class AS from_class,
    cur.asset_class AS to_class,
    COUNT(*) AS loans,

    ROUND(
        100 * COUNT(*)
        / SUM(COUNT(*)) OVER (
            PARTITION BY cur.snapshot_date, prev.asset_class
        ),
        2
    ) AS pct_of_from_class

FROM snapshot prev

JOIN snapshot cur
    ON cur.loan_id = prev.loan_id
    AND cur.snapshot_date = LAST_DAY(
        DATEADD(
            month,
            1,
            prev.snapshot_date
        )
    )

GROUP BY
    cur.snapshot_date,
    prev.asset_class,
    cur.asset_class
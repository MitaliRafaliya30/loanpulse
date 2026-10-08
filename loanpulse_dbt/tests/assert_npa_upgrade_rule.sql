-- RBI rule: an NPA loan can only move back to STANDARD (all dues cleared).
-- It must never move from NPA to SMA_0, SMA_1 or SMA_2.

WITH with_previous AS (
    SELECT
        loan_id,
        status_date,
        asset_class,
        LAG(asset_class) OVER (
            PARTITION BY loan_id
            ORDER BY status_date
        ) AS previous_class
    FROM {{ ref('fct_loan_daily_status') }}
)

SELECT *
FROM with_previous
WHERE previous_class = 'NPA'
  AND asset_class IN ('SMA_0', 'SMA_1', 'SMA_2')
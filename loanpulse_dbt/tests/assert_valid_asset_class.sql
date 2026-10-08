-- Only RBI categories are allowed, and each must match its DPD range.

SELECT
    loan_id,
    status_date,
    dpd,
    asset_class
FROM {{ ref('fct_loan_daily_status') }}
WHERE asset_class NOT IN (
    'STANDARD',
    'SMA_0',
    'SMA_1',
    'SMA_2',
    'NPA'
)
OR (asset_class = 'STANDARD' AND dpd != 0)
OR (asset_class = 'SMA_0' AND dpd NOT BETWEEN 1 AND 30)
OR (asset_class = 'SMA_1' AND dpd NOT BETWEEN 31 AND 60)
OR (asset_class = 'SMA_2' AND dpd NOT BETWEEN 61 AND 90)
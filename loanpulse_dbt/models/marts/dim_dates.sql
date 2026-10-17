-- Calendar dimension: one row per day, 4 years from spine_start_date.
-- Joins to the facts on status_date / snapshot_date.
-- Fiscal year follows the Indian financial year (April to March).
-- fiscal_year is the year the FY ends in: Apr 2026 to Mar 2027 = 2027.

WITH spine AS (
    SELECT
        DATEADD(
            day,
            ROW_NUMBER() OVER (ORDER BY seq4()) - 1,
            '{{ var("spine_start_date") }}'::date
        ) AS date_day
    FROM TABLE(GENERATOR(ROWCOUNT => 1461))
)

SELECT
    date_day,
    YEAR(date_day) AS year_number,
    QUARTER(date_day) AS quarter_number,
    MONTH(date_day) AS month_number,
    MONTHNAME(date_day) AS month_name,
    DATE_TRUNC('month', date_day) AS month_start_date,
    LAST_DAY(date_day) AS month_end_date,
    date_day = LAST_DAY(date_day) AS is_month_end,
    DAYOFWEEKISO(date_day) AS day_of_week_number,
    DAYNAME(date_day) AS day_name,
    DAYOFWEEKISO(date_day) >= 6 AS is_weekend,

    CASE
        WHEN MONTH(date_day) >= 4 THEN YEAR(date_day) + 1
        ELSE YEAR(date_day)
    END AS fiscal_year,

    CASE
        WHEN MONTH(date_day) IN (4, 5, 6) THEN 1
        WHEN MONTH(date_day) IN (7, 8, 9) THEN 2
        WHEN MONTH(date_day) IN (10, 11, 12) THEN 3
        ELSE 4
    END AS fiscal_quarter

FROM spine

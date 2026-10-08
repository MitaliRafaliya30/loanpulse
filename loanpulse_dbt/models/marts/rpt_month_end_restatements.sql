-- Compares what was REPORTED at month-end (frozen snapshot)
-- with what we know NOW after late payments arrived (daily status).
-- Banks track this to explain why old numbers differ from current data.

WITH snapshot AS (
    SELECT *
    FROM {{ ref('fct_portfolio_month_end_snapshot') }}
),

current_view AS (
    SELECT *
    FROM {{ ref('fct_loan_daily_status') }}
)

SELECT
    s.snapshot_date,
    COUNT(*) AS loans_reported,

    COUNT_IF(
        f.asset_class IS NOT NULL
        AND f.asset_class != s.asset_class
    ) AS loans_reclassified,

    ROUND(
        SUM(
            CASE
                WHEN s.asset_class = 'NPA'
                    THEN s.outstanding_principal
                ELSE 0
            END
        ),
        2
    ) AS reported_npa_outstanding,

    ROUND(
        SUM(
            CASE
                WHEN f.asset_class = 'NPA'
                    THEN f.outstanding_principal
                ELSE 0
            END
        ),
        2
    ) AS restated_npa_outstanding

FROM snapshot s

LEFT JOIN current_view f
    ON s.loan_id = f.loan_id
    AND s.snapshot_date = f.status_date

GROUP BY
    s.snapshot_date
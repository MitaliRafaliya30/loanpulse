-- 10_validate_month_end.sql
-- Checks on month-end snapshot, metrics, roll rates and restatements.

USE ROLE SYSADMIN;
USE WAREHOUSE LOANPULSE_WH;


-- 1. Snapshot: months, loans and freeze time
SELECT
    snapshot_date,
    COUNT(*) AS loans,
    MIN(snapshot_created_at) AS created_at
FROM LOANPULSE.MARTS.FCT_PORTFOLIO_MONTH_END_SNAPSHOT
GROUP BY snapshot_date
ORDER BY snapshot_date;


-- 2. Branch metrics for June 2026
SELECT
    branch_id,
    active_loans,
    ROUND(total_outstanding, 0) AS outstanding,
    gnpa_pct,
    par30_pct,
    collection_efficiency_pct
FROM LOANPULSE.MARTS.FCT_BRANCH_MONTHLY_METRICS
WHERE snapshot_date = '2026-06-30'
ORDER BY gnpa_pct DESC;


-- 3. Portfolio GNPA trend, month by month
SELECT
    snapshot_date,
    ROUND(
        100 * SUM(npa_outstanding)
        / NULLIF(SUM(total_outstanding), 0),
        2
    ) AS gnpa_pct,

    ROUND(
        100 * SUM(amount_collected)
        / NULLIF(SUM(amount_due), 0),
        2
    ) AS collection_efficiency_pct

FROM LOANPULSE.MARTS.FCT_BRANCH_MONTHLY_METRICS
GROUP BY snapshot_date
ORDER BY snapshot_date;


-- 4. Roll rates into June 2026
SELECT
    from_class,
    to_class,
    loans,
    pct_of_from_class
FROM LOANPULSE.MARTS.FCT_MONTHLY_ROLL_RATES
WHERE snapshot_date = '2026-06-30'
ORDER BY
    from_class,
    to_class;


-- 5. Reported vs restated
SELECT *
FROM LOANPULSE.MARTS.RPT_MONTH_END_RESTATEMENTS
ORDER BY snapshot_date;


-- 6. Total restatements
SELECT
    SUM(loans_reclassified) AS total_reclassified
FROM LOANPULSE.MARTS.RPT_MONTH_END_RESTATEMENTS;
-- 17_validate_corrections.sql
-- Checks payment corrections: RAW keeps every version, staging keeps the latest.

USE ROLE SYSADMIN;
USE WAREHOUSE LOANPULSE_WH;


-- 1. How many payments have more than one version in RAW (by file)?
SELECT
    COUNT(*) AS payments_with_several_files
FROM (
    SELECT collection_id
    FROM LOANPULSE.RAW.COLLECTIONS
    GROUP BY collection_id
    HAVING COUNT(DISTINCT _source_file) > 1
);


-- 2. RAW rows vs staging rows. Staging has exactly one row per payment.
SELECT
    (SELECT COUNT(*) FROM LOANPULSE.RAW.COLLECTIONS) AS raw_rows,
    (SELECT COUNT(DISTINCT collection_id) FROM LOANPULSE.RAW.COLLECTIONS) AS raw_distinct_payments,
    (SELECT COUNT(*) FROM LOANPULSE.STAGING.STG_COLLECTIONS) AS staging_rows,
    (SELECT COUNT_IF(is_corrected) FROM LOANPULSE.STAGING.STG_COLLECTIONS) AS corrected_in_staging;


-- 3. Example: every version of one corrected payment, then what staging kept
SELECT collection_id, amount, payment_mode, field_officer_id, posted_date, _source_file
FROM LOANPULSE.RAW.COLLECTIONS
WHERE collection_id = (
    SELECT MIN(collection_id)
    FROM LOANPULSE.STAGING.STG_COLLECTIONS
    WHERE is_corrected
)
ORDER BY _source_file;

SELECT collection_id, amount, payment_mode, field_officer_id,
       record_version_date, is_corrected, _source_file
FROM LOANPULSE.STAGING.STG_COLLECTIONS
WHERE collection_id = (
    SELECT MIN(collection_id)
    FROM LOANPULSE.STAGING.STG_COLLECTIONS
    WHERE is_corrected
);


-- 4. Effect on the reports.
--    Default mode (no amount changes): the total stays 328 and GNPA stays 5.18%.
--    With --with-amounts the numbers can move slightly.
SELECT SUM(loans_reclassified) AS total_reclassified
FROM LOANPULSE.MARTS.RPT_MONTH_END_RESTATEMENTS;

SELECT
    ROUND(100 * SUM(npa_outstanding) / NULLIF(SUM(total_outstanding), 0), 2) AS gnpa_pct
FROM LOANPULSE.MARTS.FCT_BRANCH_MONTHLY_METRICS
WHERE snapshot_date = '2026-06-30';

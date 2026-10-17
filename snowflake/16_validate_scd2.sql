-- 16_validate_scd2.sql
-- Checks the SCD Type 2 history tables created by dbt snapshots.
-- TRANSFORMER owns the SNAPSHOTS schema, and SYSADMIN inherits that role.

USE ROLE SYSADMIN;
USE WAREHOUSE LOANPULSE_WH;


-- 1. Versions per snapshot: total, current and closed (historical)
SELECT 'snap_branches' AS snapshot_name,
       COUNT(*) AS total_rows,
       COUNT_IF(dbt_valid_to IS NULL) AS current_rows,
       COUNT_IF(dbt_valid_to IS NOT NULL) AS historical_rows
FROM LOANPULSE.SNAPSHOTS.SNAP_BRANCHES
UNION ALL
SELECT 'snap_borrower_groups', COUNT(*),
       COUNT_IF(dbt_valid_to IS NULL), COUNT_IF(dbt_valid_to IS NOT NULL)
FROM LOANPULSE.SNAPSHOTS.SNAP_BORROWER_GROUPS
UNION ALL
SELECT 'snap_customers', COUNT(*),
       COUNT_IF(dbt_valid_to IS NULL), COUNT_IF(dbt_valid_to IS NOT NULL)
FROM LOANPULSE.SNAPSHOTS.SNAP_CUSTOMERS;


-- 2. Renamed branches: old and new version side by side
SELECT branch_id, branch_name, dbt_valid_from, dbt_valid_to
FROM LOANPULSE.SNAPSHOTS.SNAP_BRANCHES
WHERE branch_id IN (
    SELECT branch_id
    FROM LOANPULSE.SNAPSHOTS.SNAP_BRANCHES
    GROUP BY branch_id
    HAVING COUNT(*) > 1
)
ORDER BY branch_id, dbt_valid_from;


-- 3. Customers whose occupation changed (first 10)
SELECT customer_id, occupation, dbt_valid_from, dbt_valid_to
FROM LOANPULSE.SNAPSHOTS.SNAP_CUSTOMERS
WHERE customer_id IN (
    SELECT customer_id
    FROM LOANPULSE.SNAPSHOTS.SNAP_CUSTOMERS
    GROUP BY customer_id
    HAVING COUNT(*) > 1
)
ORDER BY customer_id, dbt_valid_from
LIMIT 20;


-- 4. Point-in-time lookup: what was a customer's occupation at a given time?
--    Change the timestamp and the customer id to test.
--    dbt stores dbt_valid_from / dbt_valid_to as UTC without a time zone.
--    So compare with SYSDATE() (UTC, no time zone), NOT CURRENT_TIMESTAMP()
--    (session time zone, often America/Los_Angeles). Mixing them shifts the
--    comparison by hours and the query returns no rows.
SELECT customer_id, occupation
FROM LOANPULSE.SNAPSHOTS.SNAP_CUSTOMERS
WHERE customer_id = 'CUST00001'
  AND dbt_valid_from <= SYSDATE()
  AND (dbt_valid_to IS NULL OR dbt_valid_to > SYSDATE());


-- 5. No PII columns may exist in the snapshots (must return 0 rows)
SELECT table_name, column_name
FROM LOANPULSE.INFORMATION_SCHEMA.COLUMNS
WHERE table_schema = 'SNAPSHOTS'
  AND column_name IN ('FULL_NAME', 'PHONE', 'AADHAAR_NUMBER');


-- ============================================================
-- RESET (only if a snapshot was built with the wrong columns, e.g. PII)
-- ============================================================
-- dbt adds new columns to an existing snapshot but never drops old ones,
-- so a snapshot with the wrong columns must be dropped and rebuilt.
-- This deletes its history. Do it only when no real history exists yet.
--
-- USE ROLE SYSADMIN;
-- DROP TABLE IF EXISTS LOANPULSE.SNAPSHOTS.SNAP_CUSTOMERS;
-- (then run: dbt snapshot --select snap_customers)

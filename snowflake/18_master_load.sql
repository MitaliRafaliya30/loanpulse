-- 18_master_load.sql
-- Master tables (branches, borrower_groups, customers) are loaded INSERT-ONLY
-- by the Airflow DAG: a row is inserted only if its key is new or its content
-- changed (compared with a row hash). RAW keeps every version.
-- This script prepares the RAW tables. Run it BEFORE the next DAG run.

-- ============================================================
-- 1. Add the row hash column (SYSADMIN owns the RAW tables)
-- ============================================================

USE ROLE SYSADMIN;
USE SCHEMA LOANPULSE.RAW;

ALTER TABLE BRANCHES        ADD COLUMN IF NOT EXISTS _row_hash VARCHAR;
ALTER TABLE BORROWER_GROUPS ADD COLUMN IF NOT EXISTS _row_hash VARCHAR;
ALTER TABLE CUSTOMERS       ADD COLUMN IF NOT EXISTS _row_hash VARCHAR;

-- Existing rows keep a NULL hash. On the first DAG run, every key looks
-- "changed" once, so one new version of each row is inserted and gets a hash.
-- Staging keeps the latest version, so nothing changes for the reports.


-- ============================================================
-- 2. LOADER only needs to INSERT now (least privilege)
-- ============================================================
-- The old full reload needed DELETE. Insert-only does not.

USE ROLE SECURITYADMIN;

REVOKE DELETE ON ALL TABLES IN SCHEMA LOANPULSE.RAW FROM ROLE LOADER;
REVOKE DELETE ON FUTURE TABLES IN SCHEMA LOANPULSE.RAW FROM ROLE LOADER;

SHOW GRANTS TO ROLE LOADER;


-- ============================================================
-- 3. Checks (run after the DAG has run)
-- ============================================================

USE ROLE SYSADMIN;
USE WAREHOUSE LOANPULSE_WH;

-- 3a. Rows, distinct keys and latest rows per table.
--     After the FIRST run: rows are about double the keys (old row + new version).
--     After the SECOND run: rows do not grow. The DAG log shows 0 rows inserted.
SELECT 'BRANCHES' AS table_name, COUNT(*) AS rows_in_raw,
       COUNT(DISTINCT branch_id) AS distinct_keys,
       COUNT_IF(_row_hash IS NOT NULL) AS rows_with_hash
FROM LOANPULSE.RAW.BRANCHES
UNION ALL
SELECT 'BORROWER_GROUPS', COUNT(*), COUNT(DISTINCT group_id), COUNT_IF(_row_hash IS NOT NULL)
FROM LOANPULSE.RAW.BORROWER_GROUPS
UNION ALL
SELECT 'CUSTOMERS', COUNT(*), COUNT(DISTINCT customer_id), COUNT_IF(_row_hash IS NOT NULL)
FROM LOANPULSE.RAW.CUSTOMERS;

-- 3b. Staging must have exactly one row per key (10, 779, 5000)
SELECT
    (SELECT COUNT(*) FROM LOANPULSE.STAGING.STG_BRANCHES) AS branches,
    (SELECT COUNT(*) FROM LOANPULSE.STAGING.STG_BORROWER_GROUPS) AS borrower_groups,
    (SELECT COUNT(*) FROM LOANPULSE.STAGING.STG_CUSTOMERS) AS customers;

-- 3c. Versions of a changed branch (after simulate_master_changes.py was applied
--     and loaded): the old and the new name, both kept in RAW.
SELECT branch_id, branch_name, _loaded_at, _source_file
FROM LOANPULSE.RAW.BRANCHES
WHERE branch_id = 'BR003'
ORDER BY _loaded_at;

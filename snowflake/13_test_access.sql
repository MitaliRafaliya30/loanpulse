-- 13_test_access.sql
-- Demonstrates role-based access and PII masking.


-- ============================================================
-- AS ANALYST
-- ============================================================

USE ROLE ANALYST;
USE WAREHOUSE LOANPULSE_WH;


-- 1. Customer data: PII should be masked
SELECT
    customer_id,
    full_name,
    phone,
    aadhaar_number,
    branch_name
FROM LOANPULSE.MARTS.DIM_CUSTOMERS
ORDER BY customer_id
LIMIT 3;


-- 2. Business metrics: works normally
SELECT
    branch_id,
    gnpa_pct,
    collection_efficiency_pct
FROM LOANPULSE.MARTS.FCT_BRANCH_MONTHLY_METRICS
WHERE snapshot_date = '2026-06-30'
ORDER BY gnpa_pct DESC
LIMIT 3;


-- 3. RAW data: should FAIL with an authorization error
SELECT *
FROM LOANPULSE.RAW.CUSTOMERS
LIMIT 3;


-- ============================================================
-- AS COMPLIANCE_OFFICER
-- ============================================================

USE ROLE COMPLIANCE_OFFICER;


-- 4. Same query as 1: PII should be visible
SELECT
    customer_id,
    full_name,
    phone,
    aadhaar_number,
    branch_name
FROM LOANPULSE.MARTS.DIM_CUSTOMERS
ORDER BY customer_id
LIMIT 3;


-- ============================================================
-- AS SYSADMIN
-- ============================================================

USE ROLE SYSADMIN;


-- 5. Even the admin sees masked PII
SELECT
    customer_id,
    full_name,
    phone
FROM LOANPULSE.RAW.CUSTOMERS
ORDER BY customer_id
LIMIT 3;


-- 6. Audit: who looked at unmasked data, and what did they run?
SELECT
    start_time,
    user_name,
    role_name,
    query_text
FROM TABLE(
    LOANPULSE.INFORMATION_SCHEMA.QUERY_HISTORY(
        RESULT_LIMIT => 200
    )
)
WHERE role_name = 'COMPLIANCE_OFFICER'
ORDER BY start_time DESC;
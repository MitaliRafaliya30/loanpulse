-- 06_validate_raw.sql
-- Checks that RAW tables match what the generator created.

USE ROLE SYSADMIN;
USE WAREHOUSE LOANPULSE_WH;
USE SCHEMA LOANPULSE.RAW;

-- 1. Row counts and file counts per table
SELECT 'BRANCHES' AS table_name, COUNT(*) AS row_count, COUNT(DISTINCT _source_file) AS file_count FROM BRANCHES
UNION ALL SELECT 'BORROWER_GROUPS', COUNT(*), COUNT(DISTINCT _source_file) FROM BORROWER_GROUPS
UNION ALL SELECT 'CUSTOMERS', COUNT(*), COUNT(DISTINCT _source_file) FROM CUSTOMERS
UNION ALL SELECT 'LOANS', COUNT(*), COUNT(DISTINCT _source_file) FROM LOANS
UNION ALL SELECT 'REPAYMENT_SCHEDULE', COUNT(*), COUNT(DISTINCT _source_file) FROM REPAYMENT_SCHEDULE
UNION ALL SELECT 'COLLECTIONS', COUNT(*), COUNT(DISTINCT _source_file) FROM COLLECTIONS
UNION ALL SELECT 'LOAN_WRITEOFFS', COUNT(*), COUNT(DISTINCT _source_file) FROM LOAN_WRITEOFFS
ORDER BY table_name;

-- 2. Duplicate payments (we added 93 on purpose)
SELECT COUNT(*) AS duplicate_collection_ids
FROM (
    SELECT collection_id
    FROM COLLECTIONS
    GROUP BY collection_id
    HAVING COUNT(*) > 1
);

-- 3. Payments posted after the payment date (late-arriving data)
SELECT
    COUNT_IF(posted_date > payment_date) AS late_posted,
    COUNT(*) AS total_payments
FROM COLLECTIONS;

-- 4. One example of a late-posted payment
SELECT collection_id, loan_id, payment_date, posted_date, _source_file
FROM COLLECTIONS
WHERE posted_date > payment_date
LIMIT 5;
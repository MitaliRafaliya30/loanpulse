-- 07_full_reload.sql
-- Use this ONLY when source data has been regenerated (backfill).
-- Normal daily loads use 05_load_raw.sql.
--
-- Why FORCE = TRUE: Snowflake remembers which files it already loaded.
-- After TRUNCATE, files with unchanged content would be skipped and their
-- rows would be missing. FORCE reloads every file.

USE ROLE SYSADMIN;
USE WAREHOUSE LOANPULSE_WH;
USE SCHEMA LOANPULSE.RAW;

TRUNCATE TABLE BRANCHES;
TRUNCATE TABLE BORROWER_GROUPS;
TRUNCATE TABLE CUSTOMERS;
TRUNCATE TABLE LOANS;
TRUNCATE TABLE REPAYMENT_SCHEDULE;
TRUNCATE TABLE COLLECTIONS;
TRUNCATE TABLE LOAN_WRITEOFFS;

COPY INTO BRANCHES (branch_id, branch_name, district, state, opened_date, _source_file)
FROM (SELECT $1, $2, $3, $4, $5, METADATA$FILENAME FROM @S3_RAW_STAGE/branches/)
FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT')
FORCE = TRUE;

COPY INTO BORROWER_GROUPS (group_id, branch_id, formed_date, _source_file)
FROM (SELECT $1, $2, $3, METADATA$FILENAME FROM @S3_RAW_STAGE/borrower_groups/)
FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT')
FORCE = TRUE;

COPY INTO CUSTOMERS (customer_id, full_name, phone, aadhaar_number, group_id,
                     branch_id, occupation, onboarded_date, _source_file)
FROM (SELECT $1, $2, $3, $4, $5, $6, $7, $8, METADATA$FILENAME FROM @S3_RAW_STAGE/customers/)
FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT')
FORCE = TRUE;

COPY INTO LOANS (loan_id, customer_id, product_type, principal_amount,
                 interest_rate, tenure_months, disbursement_date, _source_file)
FROM (SELECT $1, $2, $3, $4, $5, $6, $7, METADATA$FILENAME FROM @S3_RAW_STAGE/loans/)
FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT')
FORCE = TRUE;

COPY INTO REPAYMENT_SCHEDULE (loan_id, installment_number, due_date,
                              principal_due, interest_due, total_due, _source_file)
FROM (SELECT $1, $2, $3, $4, $5, $6, METADATA$FILENAME FROM @S3_RAW_STAGE/repayment_schedule/)
FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT')
FORCE = TRUE;

COPY INTO COLLECTIONS (collection_id, loan_id, payment_date, posted_date,
                       amount, payment_mode, field_officer_id, _source_file)
FROM (SELECT $1, $2, $3, $4, $5, $6, $7, METADATA$FILENAME FROM @S3_RAW_STAGE/collections/)
FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT')
FORCE = TRUE;

COPY INTO LOAN_WRITEOFFS (loan_id, writeoff_date, writeoff_amount, _source_file)
FROM (SELECT $1, $2, $3, METADATA$FILENAME FROM @S3_RAW_STAGE/loan_writeoffs/)
FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT')
FORCE = TRUE;
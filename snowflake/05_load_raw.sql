-- 05_load_raw.sql
-- Loads files from S3 into RAW tables.
-- Master tables: full reload every time (TRUNCATE + FORCE).
-- Daily tables: incremental. COPY skips files it has already loaded.

USE ROLE SYSADMIN;
USE WAREHOUSE LOANPULSE_WH;
USE SCHEMA LOANPULSE.RAW;

-- ========== MASTER DATA: full reload ==========

TRUNCATE TABLE BRANCHES;
COPY INTO BRANCHES (branch_id, branch_name, district, state, opened_date, _source_file)
FROM (
    SELECT $1, $2, $3, $4, $5, METADATA$FILENAME
    FROM @S3_RAW_STAGE/branches/
)
FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT')
FORCE = TRUE;

TRUNCATE TABLE BORROWER_GROUPS;
COPY INTO BORROWER_GROUPS (group_id, branch_id, formed_date, _source_file)
FROM (
    SELECT $1, $2, $3, METADATA$FILENAME
    FROM @S3_RAW_STAGE/borrower_groups/
)
FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT')
FORCE = TRUE;

TRUNCATE TABLE CUSTOMERS;
COPY INTO CUSTOMERS (customer_id, full_name, phone, aadhaar_number, group_id,
                     branch_id, occupation, onboarded_date, _source_file)
FROM (
    SELECT $1, $2, $3, $4, $5, $6, $7, $8, METADATA$FILENAME
    FROM @S3_RAW_STAGE/customers/
)
FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT')
FORCE = TRUE;

-- ========== DAILY DATA: incremental ==========

COPY INTO LOANS (loan_id, customer_id, product_type, principal_amount,
                 interest_rate, tenure_months, disbursement_date, _source_file)
FROM (
    SELECT $1, $2, $3, $4, $5, $6, $7, METADATA$FILENAME
    FROM @S3_RAW_STAGE/loans/
)
FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT');

COPY INTO REPAYMENT_SCHEDULE (loan_id, installment_number, due_date,
                              principal_due, interest_due, total_due, _source_file)
FROM (
    SELECT $1, $2, $3, $4, $5, $6, METADATA$FILENAME
    FROM @S3_RAW_STAGE/repayment_schedule/
)
FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT');

COPY INTO COLLECTIONS (collection_id, loan_id, payment_date, posted_date,
                       amount, payment_mode, field_officer_id, _source_file)
FROM (
    SELECT $1, $2, $3, $4, $5, $6, $7, METADATA$FILENAME
    FROM @S3_RAW_STAGE/collections/
)
FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT');

COPY INTO LOAN_WRITEOFFS (loan_id, writeoff_date, writeoff_amount, _source_file)
FROM (
    SELECT $1, $2, $3, METADATA$FILENAME
    FROM @S3_RAW_STAGE/loan_writeoffs/
)
FILE_FORMAT = (FORMAT_NAME = 'CSV_FORMAT');
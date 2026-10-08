-- 04_raw_tables.sql
-- RAW tables match the source files exactly, plus two audit columns:
--   _source_file : which S3 file the row came from
--   _loaded_at   : when the row was loaded

USE ROLE SYSADMIN;
USE SCHEMA LOANPULSE.RAW;

CREATE TABLE IF NOT EXISTS BRANCHES (
    branch_id       VARCHAR,
    branch_name     VARCHAR,
    district        VARCHAR,
    state           VARCHAR,
    opened_date     DATE,
    _source_file    VARCHAR,
    _loaded_at      TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS BORROWER_GROUPS (
    group_id        VARCHAR,
    branch_id       VARCHAR,
    formed_date     DATE,
    _source_file    VARCHAR,
    _loaded_at      TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS CUSTOMERS (
    customer_id     VARCHAR,
    full_name       VARCHAR,
    phone           VARCHAR,
    aadhaar_number  VARCHAR,
    group_id        VARCHAR,
    branch_id       VARCHAR,
    occupation      VARCHAR,
    onboarded_date  DATE,
    _source_file    VARCHAR,
    _loaded_at      TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS LOANS (
    loan_id             VARCHAR,
    customer_id         VARCHAR,
    product_type        VARCHAR,
    principal_amount    NUMBER(12,2),
    interest_rate       NUMBER(5,2),
    tenure_months       NUMBER,
    disbursement_date   DATE,
    _source_file        VARCHAR,
    _loaded_at          TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS REPAYMENT_SCHEDULE (
    loan_id             VARCHAR,
    installment_number  NUMBER,
    due_date            DATE,
    principal_due       NUMBER(12,2),
    interest_due        NUMBER(12,2),
    total_due           NUMBER(12,2),
    _source_file        VARCHAR,
    _loaded_at          TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS COLLECTIONS (
    collection_id       VARCHAR,
    loan_id             VARCHAR,
    payment_date        DATE,
    posted_date         DATE,
    amount              NUMBER(12,2),
    payment_mode        VARCHAR,
    field_officer_id    VARCHAR,
    _source_file        VARCHAR,
    _loaded_at          TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS LOAN_WRITEOFFS (
    loan_id             VARCHAR,
    writeoff_date       DATE,
    writeoff_amount     NUMBER(12,2),
    _source_file        VARCHAR,
    _loaded_at          TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);
-- 14_loader_access.sql
-- Role and service user for the Airflow load task.
-- LOADER can only load RAW. It cannot read MARTS or create objects.
-- Run after 03_stage.sql and 04_raw_tables.sql.

-- SECURITYADMIN manages users, roles and grants
USE ROLE SECURITYADMIN;


-- Role for loading raw files
CREATE ROLE IF NOT EXISTS LOADER
    COMMENT = 'Loads files from S3 into RAW tables. No access to MARTS.';

-- Standard hierarchy: SYSADMIN manages all custom roles
GRANT ROLE LOADER TO ROLE SYSADMIN;


-- ============================================================
-- What LOADER is allowed to do
-- ============================================================

GRANT USAGE
    ON WAREHOUSE LOANPULSE_WH
    TO ROLE LOADER;

GRANT USAGE
    ON DATABASE LOANPULSE
    TO ROLE LOADER;

GRANT USAGE
    ON SCHEMA LOANPULSE.RAW
    TO ROLE LOADER;

-- COPY INTO needs the stage (external stage = USAGE) and the file format
GRANT USAGE
    ON STAGE LOANPULSE.RAW.S3_RAW_STAGE
    TO ROLE LOADER;

GRANT USAGE
    ON FILE FORMAT LOANPULSE.RAW.CSV_FORMAT
    TO ROLE LOADER;

-- COPY INTO needs INSERT.
-- Master tables are reloaded with DELETE + COPY, so DELETE is needed.
-- SELECT is needed for the business date query (MAX(posted_date)).
GRANT SELECT, INSERT, DELETE
    ON ALL TABLES IN SCHEMA LOANPULSE.RAW
    TO ROLE LOADER;

GRANT SELECT, INSERT, DELETE
    ON FUTURE TABLES IN SCHEMA LOANPULSE.RAW
    TO ROLE LOADER;


-- ============================================================
-- Service user for Airflow (key pair only, no password)
-- ============================================================

-- Replace <public-key> with the line printed by generate_snowflake_key.py.
-- The DAG currently reads the same private key file as DBT_USER,
-- so the public key must match that file.
CREATE USER IF NOT EXISTS LOADER_USER
    TYPE = SERVICE
    DEFAULT_ROLE = LOADER
    DEFAULT_WAREHOUSE = LOANPULSE_WH
    RSA_PUBLIC_KEY = '<public-key>'
    COMMENT = 'Service user used by the Airflow load task';

-- CREATE USER IF NOT EXISTS skips an existing user, so its key would stay
-- unchanged. ALTER makes sure the user always has the right public key
-- (a wrong or missing key gives "JWT token is invalid").
ALTER USER LOADER_USER SET
    RSA_PUBLIC_KEY = '<public-key>';

GRANT ROLE LOADER TO USER LOADER_USER;


-- ============================================================
-- Check
-- ============================================================

SHOW GRANTS TO ROLE LOADER;

SHOW GRANTS TO USER LOADER_USER;

-- Optional test (log in as LOADER_USER or run USE ROLE LOADER):
--   SELECT COUNT(*) FROM LOANPULSE.RAW.COLLECTIONS;      -- works
--   SELECT * FROM LOANPULSE.MARTS.DIM_CUSTOMERS LIMIT 1; -- must FAIL
--   CREATE TABLE LOANPULSE.RAW.TEST_T (id INT);          -- must FAIL

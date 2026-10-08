-- 08_dbt_access.sql
-- Creates a role and a service user for dbt, with only the access it needs.

-- SECURITYADMIN manages users, roles and grants
USE ROLE SECURITYADMIN;

-- Role for transformation work
CREATE ROLE IF NOT EXISTS TRANSFORMER;

-- SYSADMIN can see everything TRANSFORMER creates (standard role hierarchy)
GRANT ROLE TRANSFORMER TO ROLE SYSADMIN;

-- What TRANSFORMER is allowed to do
GRANT USAGE ON WAREHOUSE LOANPULSE_WH TO ROLE TRANSFORMER;
GRANT USAGE ON DATABASE LOANPULSE TO ROLE TRANSFORMER;
GRANT CREATE SCHEMA ON DATABASE LOANPULSE TO ROLE TRANSFORMER;
GRANT USAGE ON SCHEMA LOANPULSE.RAW TO ROLE TRANSFORMER;
GRANT SELECT ON ALL TABLES IN SCHEMA LOANPULSE.RAW TO ROLE TRANSFORMER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA LOANPULSE.RAW TO ROLE TRANSFORMER;

-- Service user for dbt: no password, key pair only.
-- Replace <public-key> with the line printed by generate_snowflake_key.py
CREATE USER IF NOT EXISTS DBT_USER
    TYPE = SERVICE
    DEFAULT_ROLE = TRANSFORMER
    DEFAULT_WAREHOUSE = LOANPULSE_WH
    RSA_PUBLIC_KEY = '<public-key>'
    COMMENT = 'Service user used by dbt';

GRANT ROLE TRANSFORMER TO USER DBT_USER;

-- Your account identifier, needed for the dbt profile
SELECT CURRENT_ORGANIZATION_NAME() || '-' || CURRENT_ACCOUNT_NAME() AS account_identifier;
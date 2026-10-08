-- 11_masking_policies.sql
-- Masks customer PII for everyone except the COMPLIANCE_OFFICER role.
-- Requires Snowflake Enterprise edition.

USE ROLE SYSADMIN;
USE WAREHOUSE LOANPULSE_WH;

-- Separate schema for security rules, away from data
CREATE SCHEMA IF NOT EXISTS LOANPULSE.GOVERNANCE;

USE SCHEMA LOANPULSE.GOVERNANCE;


-- Masking policy for full name
CREATE MASKING POLICY IF NOT EXISTS MASK_FULL_NAME
    AS (val STRING)
    RETURNS STRING ->
        CASE
            WHEN CURRENT_ROLE() = 'COMPLIANCE_OFFICER'
                THEN val
            ELSE '*** MASKED ***'
        END
    COMMENT = 'Hides customer names from everyone except Compliance';


-- Masking policy for phone number
CREATE MASKING POLICY IF NOT EXISTS MASK_PHONE
    AS (val STRING)
    RETURNS STRING ->
        CASE
            WHEN CURRENT_ROLE() = 'COMPLIANCE_OFFICER'
                THEN val
            ELSE 'XXXXXX' || RIGHT(val, 4)
        END
    COMMENT = 'Shows only last 4 digits of phone except to Compliance';


-- Masking policy for Aadhaar number
CREATE MASKING POLICY IF NOT EXISTS MASK_AADHAAR
    AS (val STRING)
    RETURNS STRING ->
        CASE
            WHEN CURRENT_ROLE() = 'COMPLIANCE_OFFICER'
                THEN val
            ELSE 'XXXX-XXXX-' || RIGHT(val, 4)
        END
    COMMENT = 'Shows only last 4 digits of Aadhaar except to Compliance';


-- Attach the policies to the columns where PII is stored
ALTER TABLE LOANPULSE.RAW.CUSTOMERS
    MODIFY COLUMN full_name
    SET MASKING POLICY LOANPULSE.GOVERNANCE.MASK_FULL_NAME;

ALTER TABLE LOANPULSE.RAW.CUSTOMERS
    MODIFY COLUMN phone
    SET MASKING POLICY LOANPULSE.GOVERNANCE.MASK_PHONE;

ALTER TABLE LOANPULSE.RAW.CUSTOMERS
    MODIFY COLUMN aadhaar_number
    SET MASKING POLICY LOANPULSE.GOVERNANCE.MASK_AADHAAR;


-- Check: which policies are attached to which columns
SELECT
    policy_name,
    ref_column_name
FROM TABLE(
    LOANPULSE.INFORMATION_SCHEMA.POLICY_REFERENCES(
        REF_ENTITY_NAME => 'LOANPULSE.RAW.CUSTOMERS',
        REF_ENTITY_DOMAIN => 'table'
    )
)
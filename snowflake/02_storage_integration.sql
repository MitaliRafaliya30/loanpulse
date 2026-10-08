-- 02_storage_integration.sql
-- Lets Snowflake read S3 by assuming an AWS IAM role. No access keys are stored.

-- Only ACCOUNTADMIN can create integrations
USE ROLE ACCOUNTADMIN;

-- Replace the two placeholders before running.
-- Use IF NOT EXISTS: recreating the integration changes its external ID
-- and breaks the AWS trust policy.
CREATE STORAGE INTEGRATION IF NOT EXISTS S3_LOANPULSE_INT
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'S3'
    ENABLED = TRUE
    STORAGE_AWS_ROLE_ARN = '<your-role-arn>'
    STORAGE_ALLOWED_LOCATIONS = ('s3://<your-bucket>/raw/');

-- Shows the AWS user and external ID that Snowflake will use
DESC INTEGRATION S3_LOANPULSE_INT;

-- Let SYSADMIN use this integration
GRANT USAGE ON INTEGRATION S3_LOANPULSE_INT TO ROLE SYSADMIN;
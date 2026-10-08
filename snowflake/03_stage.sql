-- 03_stage.sql
-- Tells Snowflake how to read our CSV files and where they are in S3.

USE ROLE SYSADMIN;
USE WAREHOUSE LOANPULSE_WH;
USE SCHEMA LOANPULSE.RAW;

CREATE FILE FORMAT IF NOT EXISTS CSV_FORMAT
    TYPE = CSV
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL')
    EMPTY_FIELD_AS_NULL = TRUE;

-- Replace <your-bucket> before running
CREATE STAGE IF NOT EXISTS S3_RAW_STAGE
    URL = 's3://<your-bucket>/raw/'
    STORAGE_INTEGRATION = S3_LOANPULSE_INT
    FILE_FORMAT = CSV_FORMAT;

-- Connection test: should list all our files
LIST @S3_RAW_STAGE;
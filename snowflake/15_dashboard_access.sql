-- 15_dashboard_access.sql
-- Service user for the Streamlit dashboard.
-- Uses the ANALYST role, so PII is always masked in the dashboard.

USE ROLE SECURITYADMIN;

-- Replace <public-key> with the same one-line key used for the other users.
CREATE USER IF NOT EXISTS DASHBOARD_USER
    TYPE = SERVICE
    DEFAULT_ROLE = ANALYST
    DEFAULT_WAREHOUSE = LOANPULSE_WH
    RSA_PUBLIC_KEY = '<public-key>'
    COMMENT = 'Service user for the Streamlit dashboard (read only, PII masked)';

GRANT ROLE ANALYST TO USER DASHBOARD_USER;
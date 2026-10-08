-- dbt runs as TRANSFORMER, which should NEVER see real customer data.
-- If any real name, phone or Aadhaar shows up here, masking is broken.

SELECT
    customer_id,
    full_name,
    phone,
    aadhaar_number
FROM {{ ref('dim_customers') }}
WHERE full_name != '*** MASKED ***'
   OR phone NOT LIKE 'XXXXXX%'
   OR aadhaar_number NOT LIKE 'XXXX-XXXX-%'
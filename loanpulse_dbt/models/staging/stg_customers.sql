select  
    customer_id,
    full_name,
    phone,
    aadhaar_number,
    group_id,
    branch_id,
    occupation,
    onboarded_date
from {{ source('raw', 'customers') }}
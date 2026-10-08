select    
    loan_id,
    customer_id,    
    product_type,    
    principal_amount,    
    interest_rate,    
    tenure_months,    
    disbursement_date from {{ source('raw', 'loans') }}
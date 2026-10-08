select    
    loan_id,    
    installment_number,    
    due_date,    
    principal_due,    
    interest_due,    
    total_due from {{ source('raw', 'repayment_schedule') }}
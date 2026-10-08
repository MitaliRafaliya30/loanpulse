select    
    loan_id,    
    writeoff_date,    
    writeoff_amount from {{ source('raw', 'loan_writeoffs') }}
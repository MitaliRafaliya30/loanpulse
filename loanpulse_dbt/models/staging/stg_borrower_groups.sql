select    
    group_id,   
    branch_id,
    formed_date 
from {{ source('raw', 'borrower_groups') }}
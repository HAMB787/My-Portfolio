SELECT 
    customer_id, 
    MIN(created) as first_invoice_date,
    MIN(id) as first_invoice_id,  -- Assuming IDs are generated in a sequential manner
    SUM(amount_paid) as first_invoice_amount
FROM 
    {{ source('stripe', 'invoice') }}
WHERE 
    status = 'paid' AND amount_paid > 0
GROUP BY 
    customer_id
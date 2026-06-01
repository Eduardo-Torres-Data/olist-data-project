
-- CUSTOMERS 
-- 1. How many NULL do we have in every columm?
SELECT * FROM staging.customers LIMIT 100
SELECT
    COUNT(*) AS total_filas,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS null_customer_id,
    COUNT(*) FILTER (WHERE customer_unique_id IS NULL) AS null_unique_id,
    COUNT(*) FILTER (WHERE customer_zip_code_prefix IS NULL) AS null_zip,
    COUNT(*) FILTER (WHERE customer_city IS NULL) AS null_city,
    COUNT(*) FILTER (WHERE customer_state IS NULL) AS null_state
FROM staging.customers;

-- 2. How many distinct states do we have? Brazil has 27 states 
SELECT customer_state, COUNT(*) AS total
FROM staging.customers
GROUP BY customer_state
ORDER BY total DESC;

-- 3. Is there any customer id duplicated?
SELECT COUNT(*) - COUNT(DISTINCT customer_id) AS duplicados_customer_id
FROM staging.customers;


-- GEOLOCATION
-- 1. Do we have NULLs in the columms?
SELECT * FROM staging.geolocation LIMIT 100
SELECT 
    COUNT(*) FILTER (WHERE geolocation_zip_code_prefix IS NULL) AS zip_code,
    COUNT(*) FILTER (WHERE geolocation_lat IS NULL) AS lat,
    COUNT(*) FILTER (WHERE geolocation_lng IS NULL) AS lng,
    COUNT(*) FILTER (WHERE geolocation_city IS NULL) AS city,
    COUNT(*) FILTER (WHERE geolocation_state IS NULL) AS statee
FROM staging.geolocation

-- 2. How many city and states do we have registered?
SELECT
    COUNT(DISTINCT geolocation_city) AS citys,
    COUNT(DISTINCT geolocation_state) AS states
FROM staging.geolocation


-- ORDER ITEMS
-- 1. Do we have NULLs?
SELECT * FROM staging.order_items LIMIT 100
SELECT
    COUNT(*) FILTER (WHERE order_id IS NULL) AS ids,
    COUNT(*) FILTER (WHERE order_item_id IS NULL) AS id_item,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS product_id,
    COUNT(*) FILTER (WHERE seller_id IS NULL) AS seller_id,
    COUNT(*) FILTER (WHERE shipping_limit_date IS NULL) AS shipping_date,
    COUNT(*) FILTER (WHERE price IS NULL) AS price,
    COUNT(*) FILTER (WHERE freight_value IS NULL) as freight
FROM staging.order_items

-- 2. Do we have Ids duplicated? 
SELECT 
    order_id,
    order_item_id,
    COUNT(*) AS total
FROM staging.order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1

-- ORDER PAYMENTS 
SELECT * FROM staging.order_payments LIMIT 100
-- 1. Do we have NULLs?
SELECT 
    COUNT(*) FILTER (WHERE order_id IS NULL) AS ids,
    COUNT(*) FILTER ( WHERE payment_sequential IS NULL) as p_sequential,
    COUNT(*) FILTER (WHERE payment_type IS NULL) AS p_type,
    COUNT(*) FILTER (WHERE payment_installments IS NULL) AS p_installments,
    COUNT(*) FILTER (WHERE payment_value IS NULL) AS payment_value
FROM staging.order_payments

-- 2. Do we have duplicated ids?
SELECT 
    order_id,
    payment_sequential,
    COUNT(*) AS total
FROM
    staging.order_payments
GROUP BY order_id, payment_sequential
HAVING COUNT(*) > 1


-- ORDER REVIEWS
SELECT * FROM staging.order_reviews LIMIT 100
-- 1. Do we have NULLs?
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE review_id IS NULL) AS null_review_id,
    COUNT(*) FILTER (WHERE order_id IS NULL) AS null_order_id,
    COUNT(*) FILTER (WHERE review_score IS NULL) AS null_review_score,
    COUNT(*) FILTER (WHERE review_comment_title IS NULL) AS null_comment_title,
    COUNT(*) FILTER (WHERE review_comment_message IS NULL) AS null_comment_message,
    COUNT(*) FILTER (WHERE review_creation_date IS NULL) AS null_creation_date,
    COUNT(*) FILTER (WHERE review_answer_timestamp IS NULL) AS null_answer_timestamp
FROM staging.order_reviews;

-- 2. Do we have duplicated ids?
SELECT 
    review_id,
    order_id,
    COUNT (*)
FROM staging.order_reviews
GROUP BY review_id, order_id
HAVING COUNT(*) > 1

-- ORDERS
SELECT * FROM staging.orders LIMIT 100
-- 1. Do we have NULLs?
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE order_id IS NULL) AS null_order_id,
    COUNT(*) FILTER (WHERE customer_id IS NULL) AS null_customer_id,
    COUNT(*) FILTER (WHERE order_status IS NULL) AS null_status,
    COUNT(*) FILTER (WHERE order_purchase_date IS NULL) AS null_purchase_date,
    COUNT(*) FILTER (WHERE order_approved_date IS NULL) AS null_approved_date,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date_real IS NULL) AS null_carrier_date,
    COUNT(*) FILTER (WHERE order_delivered_customer_date_real IS NULL) AS null_customer_date,
    COUNT(*) FILTER (WHERE order_estimated_delivery_date_real IS NULL) AS null_estimated_date
FROM staging.orders;

SELECT
    order_status,
    COUNT(*)                                                               AS total,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date_real IS NULL)     AS null_carrier_date,
    COUNT(*) FILTER (WHERE order_delivered_customer_date_real IS NULL)    AS null_customer_date
FROM staging.orders
GROUP BY order_status
ORDER BY total DESC;

-- 2. Do we have duplicated ids?
SELECT 
    order_id,
    COUNT(*) AS total
FROM staging.orders
GROUP BY order_id
HAVING COUNT(*) > 1
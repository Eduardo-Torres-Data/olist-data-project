-- product_category_name_translation
-- Source: 71 rows, both columns text, no transformation needed
INSERT INTO public.product_category_name_translation (
    product_category_name,
    product_category_name_english
)
SELECT
    product_category_name,
    product_category_name_english
FROM staging.product_category_name_translation;

-- sellers 
INSERT INTO public.sellers (
    seller_id,
    seller_zip_code,
    seller_city,
    seller_state
)
SELECT
    seller_id,
    LPAD(seller_zip_code_prefix, 5, '0'),
    seller_city,
    seller_state 
FROM staging.sellers;


-- geolocation
-- Aggregates ~1M staging rows into one row per zip code
-- AVG for coordinates, MODE for city/state (most frequent value per zip)
INSERT INTO public.geolocation (
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
)
SELECT
    LPAD(geolocation_zip_code_prefix, 5, '0'),
    AVG(geolocation_lat::NUMERIC(9,6)),
    AVG(geolocation_lng::NUMERIC(9,6)),
    MODE() WITHIN GROUP (ORDER BY geolocation_city),
    MODE() WITHIN GROUP (ORDER BY geolocation_state)
FROM staging.geolocation
GROUP BY geolocation_zip_code_prefix;

INSERT INTO public.customers (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
)
SELECT
    customer_id,
    customer_unique_id,
    LPAD(customer_zip_code_prefix::TEXT, 5, '0'),
    customer_city,
    customer_state 
FROM staging.customers;


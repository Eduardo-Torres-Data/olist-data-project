
-- File: 04-etl-staging-to-oltp.sql
-- Purpose: Load clean data from staging schema into public OLTP schema
-- Run order follows foreign key dependencies

-- Patterns used:
--   ::TYPE             cast between types
--   LPAD(col, 5, '0')  restore leading zeros lost by integer storage
--   NULLIF(col, '')    convert empty strings to NULL before casting
--   AVG / MODE()       aggregate ~1M geolocation rows into one per zip
--   CASE WHEN IN ()    handle FK orphans by setting to NULL



-- INDEPENDENT TABLES (no foreign keys)
-- -------------------------------------------------------

-- product_category_name_translation
-- Source: 71 rows. Text to text, no transformation needed.
INSERT INTO public.product_category_name_translation (
    product_category_name,
    product_category_name_english
)
SELECT
    product_category_name,
    product_category_name_english
FROM staging.product_category_name_translation;


-- sellers
-- LPAD restores leading zeros on zip codes (varchar in staging, safe directly).
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
-- Aggregates ~1M staging rows → one row per zip code.
-- AVG for coordinates (geographic centroid), MODE for city/state (most frequent).
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


-- customers
-- customer_zip_code_prefix was INTEGER in staging (leading zeros lost).
-- ::TEXT cast before LPAD restores them.
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


-- DEPENDENT TABLES (foreign keys — load after their parents)
-- -------------------------------------------------------

-- products
-- FK orphans: 13 products reference categories not in translation table → NULL.
-- Column rename: staging typo 'lenght' corrected to 'length' via INSERT column list.
-- All dimension columns: varchar → INTEGER with NULLIF defense for empty strings.
INSERT INTO public.products (
    product_id,
    product_category_name,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)
SELECT
    product_id,
    CASE
        WHEN product_category_name IN (
            SELECT product_category_name
            FROM public.product_category_name_translation
        ) THEN product_category_name
        ELSE NULL
    END,
    NULLIF(product_name_lenght,        '')::INTEGER,
    NULLIF(product_description_lenght, '')::INTEGER,
    NULLIF(product_photos_qty,         '')::INTEGER,
    NULLIF(product_weight_g,           '')::INTEGER,
    NULLIF(product_length_cm,          '')::INTEGER,
    NULLIF(product_height_cm,          '')::INTEGER,
    NULLIF(product_width_cm,           '')::INTEGER
FROM staging.products;


-- orders
-- Column renames: staging names → clean public names (documented in design file).
-- Timestamps: staging was 'timestamp without time zone' → TIMESTAMPTZ.
INSERT INTO public.orders (
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
)
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_date::TIMESTAMPTZ,
    order_approved_date::TIMESTAMPTZ,
    order_delivered_carrier_date_real::TIMESTAMPTZ,
    order_delivered_customer_date_real::TIMESTAMPTZ,
    order_estimated_delivery_date_real::TIMESTAMPTZ
FROM staging.orders;


-- order_items
-- shipping_limit_date: varchar → TIMESTAMPTZ.
-- price / freight_value: double precision → NUMERIC(10,2) for monetary precision.
INSERT INTO public.order_items (
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value
)
SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date::TIMESTAMPTZ,
    price::NUMERIC(10,2),
    freight_value::NUMERIC(10,2)
FROM staging.order_items;

-- order_payments
-- All columns are varchar in staging.
-- payment_sequential, payment_installments → INTEGER.
-- payment_value → NUMERIC(10,2).
INSERT INTO public.order_payments (
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
)
SELECT
    order_id,
    payment_sequential::INTEGER,
    payment_type,
    GREATEST(NULLIF(payment_installments, '')::INTEGER, 1),
    NULLIF(payment_value, '')::NUMERIC(10,2)
FROM staging.order_payments;
-- This dataset does not have rows with ' ', only '0' however use GREATEST instead of COALESCE is stronger and safer 

-- order_reviews
-- review_score: varchar → INTEGER.
-- review_creation_date: varchar → TIMESTAMPTZ (NOT NULL in public).
-- review_answer_timestamp: varchar → TIMESTAMPTZ (nullable).
-- comment columns: text to text, nullable — go direct.
INSERT INTO public.order_reviews (
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
)
SELECT
    review_id,
    order_id,
    NULLIF(review_score, '')::INTEGER,
    review_comment_title,
    review_comment_message,
    NULLIF(review_creation_date,    '')::TIMESTAMPTZ,
    NULLIF(review_answer_timestamp, '')::TIMESTAMPTZ
FROM staging.order_reviews;


-- Row count comparison: staging vs public
SELECT
    'product_category_name_translation' AS tabla,
    (SELECT COUNT(*) FROM staging.product_category_name_translation) AS staging,
    (SELECT COUNT(*) FROM public.product_category_name_translation)  AS public
UNION ALL SELECT 'sellers',       (SELECT COUNT(*) FROM staging.sellers),       (SELECT COUNT(*) FROM public.sellers)
UNION ALL SELECT 'geolocation',   (SELECT COUNT(*) FROM staging.geolocation),   (SELECT COUNT(*) FROM public.geolocation)
UNION ALL SELECT 'customers',     (SELECT COUNT(*) FROM staging.customers),     (SELECT COUNT(*) FROM public.customers)
UNION ALL SELECT 'products',      (SELECT COUNT(*) FROM staging.products),      (SELECT COUNT(*) FROM public.products)
UNION ALL SELECT 'orders',        (SELECT COUNT(*) FROM staging.orders),        (SELECT COUNT(*) FROM public.orders)
UNION ALL SELECT 'order_items',   (SELECT COUNT(*) FROM staging.order_items),   (SELECT COUNT(*) FROM public.order_items)
UNION ALL SELECT 'order_payments',(SELECT COUNT(*) FROM staging.order_payments),(SELECT COUNT(*) FROM public.order_payments)
UNION ALL SELECT 'order_reviews', (SELECT COUNT(*) FROM staging.order_reviews), (SELECT COUNT(*) FROM public.order_reviews);

-- FK integrity: verify no orphaned references
SELECT 'orders → customers' AS check_name,
    COUNT(*) AS orphaned_rows
FROM public.orders o
LEFT JOIN public.customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL
UNION ALL
SELECT 'order_items → orders',
    COUNT(*) FROM public.order_items i
    LEFT JOIN public.orders o ON i.order_id = o.Porder_id
    WHERE o.order_id IS NULL
UNION ALL
SELECT 'order_payments → orders',
    COUNT(*) FROM public.order_payments p
    LEFT JOIN public.orders o ON p.order_id = o.order_id
    WHERE o.order_id IS NULL
UNION ALL
SELECT 'order_reviews → orders',
    COUNT(*) FROM public.order_reviews r
    LEFT JOIN public.orders o ON r.order_id = o.order_id
    WHERE o.order_id IS NULL;
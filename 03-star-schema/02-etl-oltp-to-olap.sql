-- Olist Brazilian E-Commerce · Star Schema ETL

-- Load order (dependency-safe):
--   1. dim_time        — generated via generate_series, no OLTP dependency
--   2. dim_customer    — source: public.customers
--   3. dim_product     — source: public.products + public.product_category_name_translation
--   4. dim_seller      — source: public.sellers
--   5. fact_orders     — source: public.orders + public.order_items (aggregated)
--   6. fact_order_items   — source: public.order_items + public.orders
--   7. fact_order_payments — source: public.order_payments
--   8. fact_order_reviews  — source: public.order_reviews

-- DIMENSIONS

-- dim_time
-- -----------------------------------------------------------------------------
-- Generated via generate_series — covers 2016-01-01 to 2018-12-31 (1,096 days).
-- date_sk format: YYYYMMDD integer (e.g. 20170315).
-- ISODOW: 1=Monday … 7=Sunday (ISO standard).
-- is_weekend: true for Saturday (6) and Sunday (7).

INSERT INTO star.dim_time (
    date_sk,
    full_date,
    year,
    quarter,
    month,
    month_name,
    day,
    day_of_week,
    day_name,
    week_of_year,
    is_weekend
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INTEGER,
    d::DATE,
    EXTRACT(YEAR    FROM d)::INTEGER,
    EXTRACT(QUARTER FROM d)::INTEGER,
    EXTRACT(MONTH   FROM d)::INTEGER,
    TO_CHAR(d, 'Month'),
    EXTRACT(DAY     FROM d)::INTEGER,
    EXTRACT(ISODOW  FROM d)::INTEGER,
    TO_CHAR(d, 'Day'),
    EXTRACT(WEEK    FROM d)::INTEGER,
    EXTRACT(ISODOW  FROM d) IN (6, 7)
FROM generate_series(
    '2016-01-01'::DATE,
    '2018-12-31'::DATE,
    '1 day'::INTERVAL
) AS d;


-- dim_customer
-- -----------------------------------------------------------------------------
-- One row per customer_id (Olist creates a new customer_id per order).
-- customer_region derived from customer_state via five-region Brazil mapping.
-- customer_zip_code sourced from customer_zip_code_prefix (TEXT in OLTP).

INSERT INTO star.dim_customer (
    customer_id,
    customer_unique_id,
    customer_city,
    customer_state,
    customer_zip_code,
    customer_region
)
SELECT
    customer_id,
    customer_unique_id,
    customer_city,
    customer_state,
    customer_zip_code_prefix,
    CASE customer_state
        WHEN 'AC' THEN 'Norte'       WHEN 'AM' THEN 'Norte'
        WHEN 'AP' THEN 'Norte'       WHEN 'PA' THEN 'Norte'
        WHEN 'RO' THEN 'Norte'       WHEN 'RR' THEN 'Norte'
        WHEN 'TO' THEN 'Norte'
        WHEN 'AL' THEN 'Nordeste'    WHEN 'BA' THEN 'Nordeste'
        WHEN 'CE' THEN 'Nordeste'    WHEN 'MA' THEN 'Nordeste'
        WHEN 'PB' THEN 'Nordeste'    WHEN 'PE' THEN 'Nordeste'
        WHEN 'PI' THEN 'Nordeste'    WHEN 'RN' THEN 'Nordeste'
        WHEN 'SE' THEN 'Nordeste'
        WHEN 'DF' THEN 'Centro-Oeste' WHEN 'GO' THEN 'Centro-Oeste'
        WHEN 'MS' THEN 'Centro-Oeste' WHEN 'MT' THEN 'Centro-Oeste'
        WHEN 'ES' THEN 'Sudeste'     WHEN 'MG' THEN 'Sudeste'
        WHEN 'RJ' THEN 'Sudeste'     WHEN 'SP' THEN 'Sudeste'
        WHEN 'PR' THEN 'Sul'         WHEN 'RS' THEN 'Sul'
        WHEN 'SC' THEN 'Sul'
        ELSE 'Desconocido'
    END AS customer_region
FROM public.customers;


-- dim_product
-- -----------------------------------------------------------------------------
-- product_category_english denormalized from product_category_name_translation.
-- LEFT JOIN preserves the 610 products with no category (NULL is intentional).

INSERT INTO star.dim_product (
    product_id,
    product_category_english,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm
)
SELECT
    p.product_id,
    t.product_category_name_english,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm
FROM public.products p
LEFT JOIN public.product_category_name_translation t
       ON p.product_category_name = t.product_category_name;


-- dim_seller
-- -----------------------------------------------------------------------------
-- seller_region derived from seller_state using the same five-region mapping
-- applied to dim_customer.

INSERT INTO star.dim_seller (
    seller_id,
    seller_zip_code,
    seller_city,
    seller_state,
    seller_region
)
SELECT
    seller_id,
    seller_zip_code,
    seller_city,
    seller_state,
    CASE seller_state
        WHEN 'AC' THEN 'Norte'       WHEN 'AM' THEN 'Norte'
        WHEN 'AP' THEN 'Norte'       WHEN 'PA' THEN 'Norte'
        WHEN 'RO' THEN 'Norte'       WHEN 'RR' THEN 'Norte'
        WHEN 'TO' THEN 'Norte'
        WHEN 'AL' THEN 'Nordeste'    WHEN 'BA' THEN 'Nordeste'
        WHEN 'CE' THEN 'Nordeste'    WHEN 'MA' THEN 'Nordeste'
        WHEN 'PB' THEN 'Nordeste'    WHEN 'PE' THEN 'Nordeste'
        WHEN 'PI' THEN 'Nordeste'    WHEN 'RN' THEN 'Nordeste'
        WHEN 'SE' THEN 'Nordeste'
        WHEN 'DF' THEN 'Centro-Oeste' WHEN 'GO' THEN 'Centro-Oeste'
        WHEN 'MS' THEN 'Centro-Oeste' WHEN 'MT' THEN 'Centro-Oeste'
        WHEN 'ES' THEN 'Sudeste'     WHEN 'MG' THEN 'Sudeste'
        WHEN 'RJ' THEN 'Sudeste'     WHEN 'SP' THEN 'Sudeste'
        WHEN 'PR' THEN 'Sul'         WHEN 'RS' THEN 'Sul'
        WHEN 'SC' THEN 'Sul'
        ELSE 'Desconocido'
    END AS seller_region
FROM public.sellers;


-- FACTS

-- fact_orders
-- -----------------------------------------------------------------------------
-- Grain: one row per order.
-- order_item_count and order_value aggregated from public.order_items via CTE.
-- LEFT JOIN on aggregated_items handles orders with no items (COALESCE → 0).
-- Nullable date columns propagate NULL automatically via TO_CHAR(NULL, ...).
-- SK resolution: customer_sk looked up from star.dim_customer by customer_id.

WITH aggregated_items AS (
    SELECT
        order_id,
        COUNT(order_item_id)::INTEGER             AS order_item_count,
        SUM(price + freight_value)::NUMERIC(10,2) AS order_value
    FROM public.order_items
    GROUP BY order_id
)
INSERT INTO star.fact_orders (
    order_id,
    customer_sk,
    order_status,
    purchase_date_sk,
    approved_date_sk,
    carrier_date_sk,
    delivered_date_sk,
    estimated_delivery_sk,
    order_item_count,
    order_value
)
SELECT
    o.order_id,
    c.customer_sk,
    o.order_status,
    TO_CHAR(o.order_purchase_timestamp,      'YYYYMMDD')::INTEGER,
    TO_CHAR(o.order_approved_at,             'YYYYMMDD')::INTEGER,
    TO_CHAR(o.order_delivered_carrier_date,  'YYYYMMDD')::INTEGER,
    TO_CHAR(o.order_delivered_customer_date, 'YYYYMMDD')::INTEGER,
    TO_CHAR(o.order_estimated_delivery_date, 'YYYYMMDD')::INTEGER,
    COALESCE(i.order_item_count, 0),
    COALESCE(i.order_value,      0.00)
FROM public.orders o
INNER JOIN star.dim_customer c ON o.customer_id = c.customer_id
LEFT  JOIN aggregated_items  i ON o.order_id    = i.order_id;


-- fact_order_items
-- -----------------------------------------------------------------------------
-- Grain: one row per item within an order.
-- customer_sk included for self-containment (avoids cross-fact joins).
-- purchase_date_sk sourced from public.orders (items share the order timestamp).
-- SK resolutions: customer_sk, product_sk, seller_sk via dim lookups.

INSERT INTO star.fact_order_items (
    order_id,
    order_item_seq,
    customer_sk,
    product_sk,
    seller_sk,
    purchase_date_sk,
    price,
    freight_value
)
SELECT
    oi.order_id,
    oi.order_item_id,
    dc.customer_sk,
    dp.product_sk,
    ds.seller_sk,
    TO_CHAR(o.order_purchase_timestamp, 'YYYYMMDD')::INTEGER,
    oi.price,
    oi.freight_value
FROM public.order_items oi
INNER JOIN public.orders       o  ON oi.order_id   = o.order_id
INNER JOIN star.dim_customer  dc  ON o.customer_id  = dc.customer_id
INNER JOIN star.dim_product   dp  ON oi.product_id  = dp.product_id
INNER JOIN star.dim_seller    ds  ON oi.seller_id   = ds.seller_id;


-- fact_order_payments
-- -----------------------------------------------------------------------------
-- Grain: one row per payment record (an order can have multiple payment types).
-- No FK to dim_time: payment records carry no independent timestamp in dataset.

INSERT INTO star.fact_order_payments (
    order_id,
    payment_type,
    payment_installments,
    payment_value
)
SELECT
    order_id,
    payment_type,
    payment_installments,
    payment_value
FROM public.order_payments;


-- fact_order_reviews
-- -----------------------------------------------------------------------------
-- Grain: one row per review record.
-- review_answer_date_sk is nullable — not all reviews receive a seller response.
-- review_id excluded: not unique in source data (profiling confirmed duplicates).

INSERT INTO star.fact_order_reviews (
    order_id,
    review_creation_date_sk,
    review_answer_date_sk,
    review_score
)
SELECT
    order_id,
    TO_CHAR(review_creation_date,  'YYYYMMDD')::INTEGER,
    TO_CHAR(review_answer_timestamp, 'YYYYMMDD')::INTEGER,
    review_score
FROM public.order_reviews;


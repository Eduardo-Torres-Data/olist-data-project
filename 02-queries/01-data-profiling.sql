
---------------- 1st step: Profiling -------------------
--------------------------------------------------------

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

-- Note: We have multiple zip codes duplicated 
SELECT geolocation_zip_code_prefix, COUNT(*) FROM staging.geolocation GROUP BY geolocation_zip_code_prefix


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

-- PRODUCT CATEGORY NAME TRANSALATION
SELECT * FROM staging.product_category_name_translation
-- 1. Do we have nulls?
SELECT
    COUNT(*)                                                          AS total_rows,
    COUNT(*) FILTER (WHERE product_category_name IS NULL)            AS null_category_pt,
    COUNT(*) FILTER (WHERE product_category_name_english IS NULL)    AS null_category_en
FROM staging.product_category_name_translation;

-- 2. Do we have duplicateds? 
SELECT
    product_category_name,
    COUNT (*) AS total
FROM staging.product_category_name_translation
GROUP BY product_category_name
HAVING COUNT(*) > 1

-- PRODUCTS
SELECT * FROM staging.products LIMIT 100
-- 1. Do we have NULLs?
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE product_id IS NULL) AS null_product_id,
    COUNT(*) FILTER (WHERE product_category_name IS NULL) AS null_category_name,
    COUNT(*) FILTER (WHERE product_name_lenght IS NULL) AS null_name_length,
    COUNT(*) FILTER (WHERE product_description_lenght IS NULL) AS null_desc_length,
    COUNT(*) FILTER (WHERE product_photos_qty IS NULL) AS null_photos_qty,
    COUNT(*) FILTER (WHERE product_weight_g IS NULL) AS null_weight,
    COUNT(*) FILTER (WHERE product_length_cm IS NULL) AS null_length,
    COUNT(*) FILTER (WHERE product_height_cm IS NULL) AS null_height,
    COUNT(*) FILTER (WHERE product_width_cm IS NULL) AS null_width
FROM staging.products;

-- Do we have duplicateds?
SELECT 
    product_id,
    COUNT (*) AS total
FROM staging.products
GROUP BY product_id
HAVING COUNT (*) > 1

-- SELLERS 
SELECT * FROM staging.sellers LIMIT 100
-- Do we have NULLs?
SELECT
    COUNT(*)                                                    AS total_rows,
    COUNT(*) FILTER (WHERE seller_id IS NULL)                  AS null_seller_id,
    COUNT(*) FILTER (WHERE seller_zip_code_prefix IS NULL)     AS null_zip_code_prefix,
    COUNT(*) FILTER (WHERE seller_city IS NULL)                AS null_city,
    COUNT(*) FILTER (WHERE seller_state IS NULL)               AS null_state
FROM staging.sellers;

-- Do we have duplicateds?
SELECT 
    seller_id,
    COUNT (*)
FROM staging.sellers
GROUP BY seller_id 
HAVING COUNT (*) > 1



-------------------- 2nd step: OLTP design --------------------
---------------------------------------------------------------


-- OLTP DESIGN DECISIONS

-- Design order: independent tables first (no FKs),
-- then tables that reference them.
-- Independent: geolocation, product_category_name_translation,
-- sellers, customers
-- Depend on above: products, orders
-- Depend on orders: order_items, order_payments, order_reviews



-- TABLE: sellers
------------------------------------------------------
-- Entity: Registered seller on the Olist platform
-- Dependencies: none (referenced by order_items)
--
-- seller_id              TEXT    NOT NULL    PRIMARY KEY
--   Alphanumeric hash from source. IDs come from Olist, not generated by us.
--
-- seller_zip_code_prefix TEXT    NOT NULL
--   Postal code stored as TEXT to preserve leading zeros (not a number).
--
-- seller_city            TEXT    nullable
--   Data has inconsistencies (mixed case, encoding issues).
--
-- seller_state           TEXT    nullable    CHECK ~'^[A-Z]{2}$'
--   2-letter Brazilian state code. Regex validates format.
--   Nullable: a few records may be missing.


-- TABLE: customers
------------------------------------------------------
-- Entity: Customer token per order. One real person can have multiple customer_ids.
-- Dependencies: none (referenced by orders)
--
-- customer_id            TEXT    NOT NULL    PRIMARY KEY
--   Per-order token. FK target from orders.customer_id.
--
-- customer_unique_id     TEXT    NOT NULL    (NOT UNIQUE)
--   Identifies the real person across orders.
--   Verified: 99,441 rows vs 96,096 unique values — same person appears
--   multiple times if they placed multiple orders.
--
-- customer_zip_code_prefix TEXT  NOT NULL    CHECK ~'^\d{5}$'
--   5-digit Brazilian postal prefix.
--   NOTE: staging stored this as INTEGER, silently stripping leading zeros.
--   ETL will apply LPAD(value, 5, '0') before insert.
--
-- customer_city          TEXT    nullable
--   Inconsistencies found in profiling. Allow null.
--
-- customer_state         TEXT    NOT NULL    CHECK ~'^[A-Z]{2}$'
--   No nulls found in profiling. Always 2-letter Brazilian state code.


-- TABLE: product_category_name_translation
------------------------------------------------------
-- Entity: Lookup table — Portuguese to English category name mapping
-- Dependencies: none (referenced by products)
--
-- product_category_name         TEXT    NOT NULL    PRIMARY KEY
--   Portuguese category name. FK target from products.product_category_name.
--   PRIMARY KEY implies NOT NULL in PostgreSQL.
--
-- product_category_name_english TEXT    NOT NULL    UNIQUE
--   English translation. NOT NULL: all categories must have a translation.
--   UNIQUE: two different categories cannot share the same English name.
--   Note: UNIQUE alone does not prevent NULLs in PostgreSQL.


-- TABLE: geolocation
------------------------------------------------------
-- Entity: Geographic coordinates per Brazilian zip code prefix
-- Dependencies: none (referenced by customers, sellers indirectly)
-- NOTE: staging has ~1M rows with duplicate zip codes (multiple measurements
-- per zip). ETL will aggregate using AVG(lat)/AVG(lng) GROUP BY zip.
-- Result: one row per zip in the clean table.
--
-- geolocation_zip_code_prefix  TEXT          NOT NULL  PRIMARY KEY
--   5-digit postal prefix. Unique after ETL aggregation.
--   ETL will apply LPAD(value, 5, '0') for leading zeros (same issue as customers).
--
-- geolocation_lat              NUMERIC(9,6)  NOT NULL
--   Latitude. Valid range: -90 to 90.
--   CHECK (geolocation_lat BETWEEN -90 AND 90)
--
-- geolocation_lng              NUMERIC(9,6)  NOT NULL
--   Longitude. Valid range: -180 to 180.
--   CHECK (geolocation_lng BETWEEN -180 AND 180)
--
-- geolocation_city             TEXT          NOT NULL
--   City name after aggregation. Mode (most frequent value) used if multiple.
--
-- geolocation_state            TEXT          NOT NULL  CHECK ~'^[A-Z]{2}$'
--   2-letter Brazilian state code.


-- TABLE: products
------------------------------------------------------
-- Entity: Product listed on the Olist platform
-- Dependencies: product_category_name_translation
--
-- product_id                  TEXT     NOT NULL  PRIMARY KEY
--
-- product_category_name       TEXT     nullable
--   FK → product_category_name_translation.product_category_name
--   ON DELETE RESTRICT
--   Nullable: 610 products have no category assigned (confirmed in profiling).
--
-- product_name_length         INTEGER  nullable  (typo fixed: 'lenght' → 'length')
--   Number of characters in product name. 610 nulls in profiling.
--
-- product_description_length  INTEGER  nullable  (typo fixed)
--   Number of characters in product description. 610 nulls.
--
-- product_photos_qty          INTEGER  nullable
--   Number of product photos. 610 nulls.
--
-- product_weight_g            INTEGER  nullable
--   Weight in grams. 2 nulls in profiling.
--
-- product_length_cm           INTEGER  nullable
--   Length in centimeters. 2 nulls.
--
-- product_height_cm           INTEGER  nullable
--   Height in centimeters. 2 nulls.
--
-- product_width_cm            INTEGER  nullable
--   Width in centimeters. 2 nulls.


-- TABLE: orders
------------------------------------------------------
-- Entity: A purchase order placed by a customer
-- Dependencies: customers
--
-- order_id                      TEXT        NOT NULL  PRIMARY KEY
--
-- customer_id                   TEXT        NOT NULL
--   FK → customers.customer_id  ON DELETE RESTRICT
--   Every order must belong to a customer.
--
-- order_status                  TEXT        NOT NULL
--   CHECK (order_status IN (
--     'delivered','shipped','canceled','unavailable',
--     'invoiced','processing','created','approved'))
--   8 valid statuses confirmed in profiling.
--
-- order_purchase_timestamp      TIMESTAMPTZ NOT NULL
--   Always set at purchase time. 0 nulls in profiling.
--
-- order_approved_at             TIMESTAMPTZ
--   160 nulls in profiling (structural: orders canceled before approval).
--
-- order_delivered_carrier_date  TIMESTAMPTZ
--   1783 nulls (structural: orders not yet shipped).
--
-- order_delivered_customer_date TIMESTAMPTZ
--   2965 nulls (structural: orders not yet delivered).
--
-- order_estimated_delivery_date TIMESTAMPTZ NOT NULL
--   0 nulls in profiling. Always assigned at purchase time.


-- TABLE: order_items
------------------------------------------------------
-- Entity: Individual item within an order
-- Dependencies: orders, products, sellers
--
-- order_id        TEXT          NOT NULL
--   Part of composite PK. FK → orders.order_id  ON DELETE CASCADE
--
-- order_item_id   INTEGER       NOT NULL
--   Sequential item number within an order (1, 2, 3...).
--   Part of composite PK.
--
-- PRIMARY KEY (order_id, order_item_id)
--
-- product_id      TEXT          NOT NULL
--   FK → products.product_id  ON DELETE RESTRICT
--
-- seller_id       TEXT          NOT NULL
--   FK → sellers.seller_id  ON DELETE RESTRICT
--
-- shipping_limit_date  TIMESTAMPTZ  NOT NULL
--   Deadline for seller to hand package to carrier. 0 nulls in profiling.
--
-- price           NUMERIC(10,2) NOT NULL
--   Item price. CHECK (price >= 0)
--
-- freight_value   NUMERIC(10,2) NOT NULL
--   Shipping cost for this item. CHECK (freight_value >= 0)


-- TABLE: order_payments
------------------------------------------------------
-- Entity: Payment entry for an order (one order can have multiple payment methods)
-- Dependencies: orders
--
-- order_id             TEXT          NOT NULL
--   Part of composite PK. FK → orders.order_id  ON DELETE CASCADE
--
-- payment_sequential   INTEGER       NOT NULL
--   Sequential payment number within an order. CHECK (payment_sequential > 0)
--   Part of composite PK.
--
-- PRIMARY KEY (order_id, payment_sequential)
--
-- payment_type         TEXT          NOT NULL
--   CHECK (payment_type IN
--     ('credit_card','boleto','debit_card','voucher','not_defined'))
--
-- payment_installments INTEGER       NOT NULL
--   Number of installments. CHECK (payment_installments > 0)
--
-- payment_value        NUMERIC(10,2) NOT NULL
--   CHECK (payment_value >= 0)
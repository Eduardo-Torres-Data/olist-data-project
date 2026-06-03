-- File: 03-create-oltp-tables.sql
-- Purpose: DDL for the clean OLTP layer (public schema)
-- Tables are empty after creation — data loaded via ETL (next phase)

-- Column renames from staging:
--   product_name_lenght        - product_name_length
--   product_description_lenght - product_description_length
--   order_purchase_date        - order_purchase_timestamp
--   order_delivered_carrier_date_real  - order_delivered_carrier_date
--   order_delivered_customer_date_real - order_delivered_customer_date
--   order_estimated_delivery_date_real - order_estimated_delivery_date



-- Drop in reverse dependency order (safe re-run)
DROP TABLE IF EXISTS public.order_reviews                     CASCADE;
DROP TABLE IF EXISTS public.order_payments                    CASCADE;
DROP TABLE IF EXISTS public.order_items                       CASCADE;
DROP TABLE IF EXISTS public.orders                            CASCADE;
DROP TABLE IF EXISTS public.products                          CASCADE;
DROP TABLE IF EXISTS public.customers                         CASCADE;
DROP TABLE IF EXISTS public.sellers                           CASCADE;
DROP TABLE IF EXISTS public.product_category_name_translation CASCADE;
DROP TABLE IF EXISTS public.geolocation                       CASCADE;



-- INDEPENDENT TABLES (no foreign keys)
-- -------------------------------------------------------

-- Geographic reference per zip code prefix.
-- NOTE: staging has ~1M rows (multiple measurements per zip).
-- ETL will aggregate: AVG(lat/lng), MODE(city/state) GROUP BY zip.
-- ETL will also LPAD zip codes to 5 digits (integer storage stripped leading zeros).
CREATE TABLE public.geolocation (
    geolocation_zip_code_prefix TEXT         NOT NULL,
    geolocation_lat             NUMERIC(9,6) NOT NULL,
    geolocation_lng             NUMERIC(9,6) NOT NULL,
    geolocation_city            TEXT         NOT NULL,
    geolocation_state           TEXT         NOT NULL,

    CONSTRAINT pk_geolocation   PRIMARY KEY (geolocation_zip_code_prefix),
    CONSTRAINT ck_geo_lat       CHECK (geolocation_lat  BETWEEN -90  AND 90),
    CONSTRAINT ck_geo_lng       CHECK (geolocation_lng  BETWEEN -180 AND 180),
    CONSTRAINT ck_geo_state     CHECK (geolocation_state ~ '^[A-Z]{2}$')
);

-- Lookup table: Portuguese category name to English translation.
CREATE TABLE public.product_category_name_translation (
    product_category_name         TEXT NOT NULL,
    product_category_name_english TEXT NOT NULL,

    CONSTRAINT pk_category_translation PRIMARY KEY (product_category_name),
    CONSTRAINT uq_category_english     UNIQUE      (product_category_name_english)
);

-- Registered sellers on the platform.
CREATE TABLE public.sellers (
    seller_id       TEXT NOT NULL,
    seller_zip_code TEXT NOT NULL,
    seller_city     TEXT,
    seller_state    TEXT,

    CONSTRAINT pk_sellers      PRIMARY KEY (seller_id),
    CONSTRAINT ck_seller_state CHECK (seller_state ~ '^[A-Z]{2}$')
);

-- Customer token per order. One real person can have multiple customer_ids.
-- customer_unique_id identifies the real person but is NOT unique in this table
-- (verified: 99,441 rows vs 96,096 distinct persons).
CREATE TABLE public.customers (
    customer_id              TEXT NOT NULL,
    customer_unique_id       TEXT NOT NULL,
    customer_zip_code_prefix TEXT NOT NULL,
    customer_city            TEXT,
    customer_state           TEXT NOT NULL,

    CONSTRAINT pk_customers      PRIMARY KEY (customer_id),
    CONSTRAINT ck_customer_zip   CHECK (customer_zip_code_prefix ~ '^\d{5}$'),
    CONSTRAINT ck_customer_state CHECK (customer_state ~ '^[A-Z]{2}$')
);

-- TABLES WITH FOREIGN KEYS (dependency order)
-- -------------------------------------------------------

-- Product catalog.
-- ~610 products have no category (FK column is nullable by design).
-- Column name typos corrected from staging ('lenght' - 'length').
CREATE TABLE public.products (
    product_id                 TEXT    NOT NULL,
    product_category_name      TEXT,
    product_name_length        INTEGER,
    product_description_length INTEGER,
    product_photos_qty         INTEGER,
    product_weight_g           INTEGER,
    product_length_cm          INTEGER,
    product_height_cm          INTEGER,
    product_width_cm           INTEGER,

    CONSTRAINT pk_products         PRIMARY KEY (product_id),
    CONSTRAINT fk_product_category FOREIGN KEY (product_category_name)
        REFERENCES public.product_category_name_translation (product_category_name)
        ON DELETE RESTRICT
);

-- Purchase orders placed by customers.
-- Structural nulls in date columns explained in profiling (01-data-profiling.sql).
CREATE TABLE public.orders (
    order_id                      TEXT        NOT NULL,
    customer_id                   TEXT        NOT NULL,
    order_status                  TEXT        NOT NULL,
    order_purchase_timestamp      TIMESTAMPTZ NOT NULL,
    order_approved_at             TIMESTAMPTZ,
    order_delivered_carrier_date  TIMESTAMPTZ,
    order_delivered_customer_date TIMESTAMPTZ,
    order_estimated_delivery_date TIMESTAMPTZ NOT NULL,

    CONSTRAINT pk_orders         PRIMARY KEY (order_id),
    CONSTRAINT fk_order_customer FOREIGN KEY (customer_id)
        REFERENCES public.customers (customer_id)
        ON DELETE RESTRICT,
    CONSTRAINT ck_order_status   CHECK (order_status IN (
        'delivered','shipped','canceled','unavailable',
        'invoiced','processing','created','approved'))
);

-- Individual items within an order.
-- Composite PK: one order can contain multiple items.
CREATE TABLE public.order_items (
    order_id            TEXT          NOT NULL,
    order_item_id       INTEGER       NOT NULL,
    product_id          TEXT          NOT NULL,
    seller_id           TEXT          NOT NULL,
    shipping_limit_date TIMESTAMPTZ   NOT NULL,
    price               NUMERIC(10,2) NOT NULL,
    freight_value       NUMERIC(10,2) NOT NULL,

    CONSTRAINT pk_order_items   PRIMARY KEY (order_id, order_item_id),
    CONSTRAINT fk_items_order   FOREIGN KEY (order_id)
        REFERENCES public.orders   (order_id)   ON DELETE CASCADE,
    CONSTRAINT fk_items_product FOREIGN KEY (product_id)
        REFERENCES public.products (product_id) ON DELETE RESTRICT,
    CONSTRAINT fk_items_seller  FOREIGN KEY (seller_id)
        REFERENCES public.sellers  (seller_id)  ON DELETE RESTRICT,
    CONSTRAINT ck_price         CHECK (price         >= 0),
    CONSTRAINT ck_freight       CHECK (freight_value >= 0)
);

-- Payments for an order. One order can have multiple payment methods.
CREATE TABLE public.order_payments (
    order_id             TEXT          NOT NULL,
    payment_sequential   INTEGER       NOT NULL,
    payment_type         TEXT          NOT NULL,
    payment_installments INTEGER       NOT NULL,
    payment_value        NUMERIC(10,2) NOT NULL,

    CONSTRAINT pk_order_payments       PRIMARY KEY (order_id, payment_sequential),
    CONSTRAINT fk_payments_order       FOREIGN KEY (order_id)
        REFERENCES public.orders (order_id) ON DELETE CASCADE,
    CONSTRAINT ck_payment_sequential   CHECK (payment_sequential   >  0),
    CONSTRAINT ck_payment_installments CHECK (payment_installments >  0),
    CONSTRAINT ck_payment_type         CHECK (payment_type IN (
        'credit_card','boleto','debit_card','voucher','not_defined')),
    CONSTRAINT ck_payment_value        CHECK (payment_value        >= 0)
);

-- Customer reviews for orders.
-- review_id is NOT unique in staging — composite PK (review_id, order_id) required.
CREATE TABLE public.order_reviews (
    review_id               TEXT        NOT NULL,
    order_id                TEXT        NOT NULL,
    review_score            INTEGER     NOT NULL,
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    TIMESTAMPTZ NOT NULL,
    review_answer_timestamp TIMESTAMPTZ,

    CONSTRAINT pk_order_reviews PRIMARY KEY (review_id, order_id),
    CONSTRAINT fk_reviews_order FOREIGN KEY (order_id)
        REFERENCES public.orders (order_id) ON DELETE CASCADE,
    CONSTRAINT ck_review_score  CHECK (review_score BETWEEN 1 AND 5)
);
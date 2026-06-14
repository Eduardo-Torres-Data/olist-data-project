-- Olist Brazilian E-Commerce · Star Schema DDL

-- Schema  : star
-- Project : olist-data-project
-- Author  : Eduardo Torres
-- Created : 2026
--
-- Description:
--   Dimensional model (star schema) built on top of the cleaned OLTP schema
--   (public.*). Optimized for analytical queries and Tableau dashboards.
--
-- Object inventory (8 tables):
--   Dimensions : dim_time, dim_customer, dim_product, dim_seller
--   Facts      : fact_orders, fact_order_items, fact_order_payments,
--                fact_order_reviews
--
-- Load order:
--   1. Create schema
--   2. Dimensions (no FK dependencies)
--   3. Facts (FK dependencies on dimensions)


-- SCHEMA

CREATE SCHEMA star;


-- DIMENSIONS


-- dim_time
-- -----------------------------------------------------------------------------
-- One row per calendar day covering the full dataset range (2016-01-01 to
-- 2018-12-31). Populated via generate_series — not sourced from OLTP data.
--
-- Design note: date_sk uses YYYYMMDD integer format (e.g. 20170315) instead
-- of SERIAL. This is the standard exception to the surrogate-key-has-no-meaning
-- rule: the value is self-documenting and enables range filtering without joins.
-- -----------------------------------------------------------------------------

CREATE TABLE star.dim_time (
    date_sk         INTEGER       NOT NULL,
    full_date       DATE          NOT NULL,
    year            INTEGER       NOT NULL,
    quarter         INTEGER       NOT NULL,  -- 1–4
    month           INTEGER       NOT NULL,  -- 1–12
    month_name      VARCHAR(20)   NOT NULL,  -- 'January' … 'December'
    day             INTEGER       NOT NULL,  -- 1–31
    day_of_week     INTEGER       NOT NULL,  -- 1=Monday, 7=Sunday
    day_name        VARCHAR(20)   NOT NULL,  -- 'Monday' … 'Sunday'
    week_of_year    INTEGER       NOT NULL,  -- 1–53
    is_weekend      BOOLEAN       NOT NULL,

    CONSTRAINT pk_dim_time
        PRIMARY KEY (date_sk),
    CONSTRAINT uq_dim_time_full_date
        UNIQUE (full_date),
    CONSTRAINT chk_dim_time_quarter
        CHECK (quarter BETWEEN 1 AND 4),
    CONSTRAINT chk_dim_time_month
        CHECK (month BETWEEN 1 AND 12),
    CONSTRAINT chk_dim_time_day
        CHECK (day BETWEEN 1 AND 31),
    CONSTRAINT chk_dim_time_day_of_week
        CHECK (day_of_week BETWEEN 1 AND 7),
    CONSTRAINT chk_dim_time_week_of_year
        CHECK (week_of_year BETWEEN 1 AND 53)
);



-- dim_customer
-- -----------------------------------------------------------------------------
-- One row per customer_id (not per person — Olist generates a new customer_id
-- per order). customer_unique_id identifies the actual person across orders.
--
-- customer_region is a derived column (computed from customer_state in ETL)
-- stored here to simplify regional aggregations without repeated CASE WHEN.
--
-- Source: public.customers

CREATE TABLE star.dim_customer (
    customer_sk         SERIAL,
    customer_id         TEXT          NOT NULL,  -- natural key (1 per order)
    customer_unique_id  TEXT          NOT NULL,  -- real person identifier
    customer_city       TEXT,                    -- nullable: 0 nulls in source but kept flexible
    customer_state      TEXT          NOT NULL,
    customer_zip_code   TEXT          NOT NULL,
    customer_region     TEXT          NOT NULL,  -- derived: Norte/Nordeste/Centro-Oeste/Sudeste/Sul

    CONSTRAINT pk_dim_customer
        PRIMARY KEY (customer_sk),
    CONSTRAINT uq_dim_customer_customer_id
        UNIQUE (customer_id)
);


-- dim_product
-- -----------------------------------------------------------------------------
-- One row per product. product_category_english is the denormalized translation
-- (merged from public.product_category_name_translation in ETL).
-- 610 products have no category — nullable is intentional.
--
-- Columns dropped from OLTP: product_name_length, product_description_length
-- (metadata with no analytical value).
--
-- Source: public.products + public.product_category_name_translation

CREATE TABLE star.dim_product (
    product_sk               SERIAL,
    product_id               TEXT          NOT NULL,
    product_category_english TEXT,                    -- nullable: 610 products uncategorized
    product_weight_g         INTEGER,                 -- nullable: missing in source
    product_length_cm        INTEGER,                 -- nullable: missing in source
    product_height_cm        INTEGER,                 -- nullable: missing in source
    product_width_cm         INTEGER,                 -- nullable: missing in source

    CONSTRAINT pk_dim_product
        PRIMARY KEY (product_sk),
    CONSTRAINT uq_dim_product_product_id
        UNIQUE (product_id)
);


-- dim_seller
-- -----------------------------------------------------------------------------
-- One row per seller. seller_region derived from seller_state using the same
-- five-region mapping applied to dim_customer.
--
-- Source: public.sellers

CREATE TABLE star.dim_seller (
    seller_sk       SERIAL,
    seller_id       TEXT          NOT NULL,
    seller_zip_code TEXT          NOT NULL,
    seller_city     TEXT          NOT NULL,
    seller_state    TEXT          NOT NULL,
    seller_region   TEXT          NOT NULL,  -- derived: Norte/Nordeste/Centro-Oeste/Sudeste/Sul

    CONSTRAINT pk_dim_seller
        PRIMARY KEY (seller_sk),
    CONSTRAINT uq_dim_seller_seller_id
        UNIQUE (seller_id)
);


-- FACTS


-- fact_orders
-- -----------------------------------------------------------------------------
-- Grain: one row per order.
--
-- Role-playing dimensions: dim_time is referenced five times with different
-- aliases, one per order lifecycle timestamp:
--   purchase_date_sk     → when the customer placed the order       (NOT NULL)
--   approved_date_sk     → when payment was approved                (nullable)
--   carrier_date_sk      → when the carrier picked up the shipment  (nullable)
--   delivered_date_sk    → when the customer received the order     (nullable)
--   estimated_delivery_sk → Olist's promised delivery date          (NOT NULL)
--
-- Nullable dates reflect the order lifecycle: an order always has a purchase
-- and an estimate, but may never be approved, shipped, or delivered.
--
-- Degenerate dimensions: order_id (no own attributes → no dim table needed),
--   order_status (8 distinct values → dim_status would add no analytical value).
--
-- Metrics: order_item_count, order_value (base metrics — calculations like
--   avg_ticket or days_to_deliver live in queries, not stored here).
--
-- Source: public.orders + public.order_items (aggregated)

CREATE TABLE star.fact_orders (
    order_sk                SERIAL,
    order_id                TEXT            NOT NULL,   -- degenerate dimension
    customer_sk             INTEGER         NOT NULL,
    order_status            TEXT            NOT NULL,   -- degenerate dimension
    purchase_date_sk        INTEGER         NOT NULL,
    approved_date_sk        INTEGER,                    -- nullable: not all orders get approved
    carrier_date_sk         INTEGER,                    -- nullable: not all orders get shipped
    delivered_date_sk       INTEGER,                    -- nullable: not all orders get delivered
    estimated_delivery_sk   INTEGER         NOT NULL,
    order_item_count        INTEGER         NOT NULL,   -- metric
    order_value             NUMERIC(10,2)   NOT NULL,   -- metric

    CONSTRAINT pk_fact_orders
        PRIMARY KEY (order_sk),
    CONSTRAINT uq_fact_orders_order_id
        UNIQUE (order_id),
    CONSTRAINT fk_fact_orders_customer
        FOREIGN KEY (customer_sk)
        REFERENCES star.dim_customer (customer_sk),
    CONSTRAINT fk_fact_orders_purchase_date
        FOREIGN KEY (purchase_date_sk)
        REFERENCES star.dim_time (date_sk),
    CONSTRAINT fk_fact_orders_approved_date
        FOREIGN KEY (approved_date_sk)
        REFERENCES star.dim_time (date_sk),
    CONSTRAINT fk_fact_orders_carrier_date
        FOREIGN KEY (carrier_date_sk)
        REFERENCES star.dim_time (date_sk),
    CONSTRAINT fk_fact_orders_delivered_date
        FOREIGN KEY (delivered_date_sk)
        REFERENCES star.dim_time (date_sk),
    CONSTRAINT fk_fact_orders_estimated_delivery
        FOREIGN KEY (estimated_delivery_sk)
        REFERENCES star.dim_time (date_sk)
);


-- fact_order_items
-- -----------------------------------------------------------------------------
-- Grain: one row per item within an order (an order can have multiple items
-- from different sellers).
--
-- customer_sk is included here (even though the customer belongs to the order)
-- to keep the fact self-contained: fact tables must answer analytical questions
-- by joining only to their own dimensions, never to another fact table.
--
-- order_item_seq identifies the item position within its order (1, 2, 3 …).
-- order_id is a degenerate dimension used to group all items of the same order.
--
-- Only one date FK (purchase_date_sk) because items share the order's purchase
-- timestamp — the other four lifecycle timestamps belong to fact_orders.
--
-- Source: public.order_items + public.orders (for customer_id and purchase date)

CREATE TABLE star.fact_order_items (
    order_item_sk       SERIAL,
    order_id            TEXT            NOT NULL,   -- degenerate dimension
    order_item_seq      INTEGER         NOT NULL,   -- item position within order
    customer_sk         INTEGER         NOT NULL,
    product_sk          INTEGER         NOT NULL,
    seller_sk           INTEGER         NOT NULL,
    purchase_date_sk    INTEGER         NOT NULL,
    price               NUMERIC(10,2)   NOT NULL,   -- metric
    freight_value       NUMERIC(10,2)   NOT NULL,   -- metric

    CONSTRAINT pk_fact_order_items
        PRIMARY KEY (order_item_sk),
    CONSTRAINT fk_fact_order_items_customer
        FOREIGN KEY (customer_sk)
        REFERENCES star.dim_customer (customer_sk),
    CONSTRAINT fk_fact_order_items_product
        FOREIGN KEY (product_sk)
        REFERENCES star.dim_product (product_sk),
    CONSTRAINT fk_fact_order_items_seller
        FOREIGN KEY (seller_sk)
        REFERENCES star.dim_seller (seller_sk),
    CONSTRAINT fk_fact_order_items_purchase_date
        FOREIGN KEY (purchase_date_sk)
        REFERENCES star.dim_time (date_sk)
);


-- fact_order_payments
-- -----------------------------------------------------------------------------
-- Grain: one row per payment record. A single order can have multiple payment
-- records (e.g. credit card + voucher split).
--
-- No FK to dim_time: payment records in the Olist dataset carry no independent
-- timestamp — date context is inherited from the order (fact_orders).
--
-- Degenerate dimensions: order_id (links back to the order for grouping),
--   payment_type (e.g. 'credit_card', 'boleto' — no own attributes).
--
-- Source: public.order_payments

CREATE TABLE star.fact_order_payments (
    payment_sk           SERIAL,
    order_id             TEXT            NOT NULL,   -- degenerate dimension
    payment_type         TEXT            NOT NULL,   -- degenerate dimension
    payment_installments INTEGER         NOT NULL,   -- metric
    payment_value        NUMERIC(10,2)   NOT NULL,   -- metric

    CONSTRAINT pk_fact_order_payments
        PRIMARY KEY (payment_sk)
);


-- fact_order_reviews
-- -----------------------------------------------------------------------------
-- Grain: one row per review. In this dataset most orders have one review, but
-- ~551 orders have duplicate review records (source data quality issue).
--
-- review_id is excluded: it is NOT unique in the source (profiling confirmed
-- duplicate review_ids across different orders). order_id is sufficient to
-- identify and group reviews.
--
-- review_answer_date_sk is nullable: not all reviews receive a seller response.
--
-- Source: public.order_reviews

CREATE TABLE star.fact_order_reviews (
    review_sk                SERIAL,
    order_id                 TEXT          NOT NULL,   -- degenerate dimension
    review_creation_date_sk  INTEGER       NOT NULL,
    review_answer_date_sk    INTEGER,                  -- nullable: not all reviews get a response
    review_score             INTEGER       NOT NULL,   -- metric (1–5 stars)

    CONSTRAINT pk_fact_order_reviews
        PRIMARY KEY (review_sk),
    CONSTRAINT fk_fact_order_reviews_creation_date
        FOREIGN KEY (review_creation_date_sk)
        REFERENCES star.dim_time (date_sk),
    CONSTRAINT fk_fact_order_reviews_answer_date
        FOREIGN KEY (review_answer_date_sk)
        REFERENCES star.dim_time (date_sk)
);



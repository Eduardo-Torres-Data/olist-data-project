-- Olist Brazilian E-Commerce · Star Schema Analytical Queries
-- Schema  : star
-- Project : olist-data-project
-- Author  : Eduardo Torres
-- Created : 2026
--
-- Description:
--   Analytical queries built on top of the star schema (star.*).
--   Demonstrates dimensional modeling patterns: role-playing dimensions,
--   degenerate dimension grouping, and cross-fact joins via shared keys.


-- Total Revenue and orders per region
SELECT 
    dc.customer_region,
    SUM(fo.order_value) AS total_revenue,
    COUNT(DISTINCT fo.order_id) AS total_orders
FROM 
    star.dim_customer dc 
INNER JOIN star.fact_orders fo ON fo.customer_sk = dc.customer_sk
GROUP BY dc.customer_region
ORDER BY total_revenue DESC, total_orders DESC;


-- Top 10 categories per revenue, average ticket and volume
WITH info AS (
    SELECT
        COALESCE(dp.product_category_english, 'Uncategorized') AS category,
        SUM(foi.price) AS total_revenue,
        COUNT(DISTINCT foi.order_id) AS orders_volume,
        COUNT(foi.order_item_sk) AS items_volume,
        SUM(foi.price) / NULLIF(COUNT(DISTINCT foi.order_id), 0) AS avg_ticket_per_order,
        SUM(foi.price) / NULLIF(COUNT(foi.order_item_sk), 0) AS avg_ticket_per_item
    FROM star.dim_product dp
    INNER JOIN star.fact_order_items foi ON foi.product_sk = dp.product_sk
    GROUP BY dp.product_category_english
)
SELECT
    category,
    ROUND(total_revenue, 2)        AS total_revenue,
    orders_volume,
    items_volume,
    ROUND(avg_ticket_per_order, 2) AS avg_ticket_per_order,
    ROUND(avg_ticket_per_item, 2)  AS avg_ticket_per_item
FROM info
ORDER BY total_revenue DESC
LIMIT 10;


-- Monthly revenue trend — 2017 vs 2018
-- Business question: How did monthly revenue evolve across 2017 and 2018?

WITH info AS (
    SELECT 
        dt.year AS year,
        dt.month AS month,
        dt.month_name AS month_name,
        SUM(foi.price) AS total_revenue
    FROM star.fact_order_items foi 
    INNER JOIN star.dim_time dt ON dt.date_sk = foi.purchase_date_sk
    GROUP BY dt.year, dt.month, dt.month_name
)
SELECT 
    i.year,
    i.month,
    i.month_name,
    i.total_revenue,
    ROUND(((i.total_revenue - NULLIF(LAG(i.total_revenue,12) OVER (ORDER BY i.year ASC, i.month ASC),0)) /
     NULLIF(LAG(i.total_revenue,12) OVER (ORDER BY i.year ASC, i.month ASC),0) * 100),2) AS vs_previous_year
FROM info i
WHERE i.year BETWEEN 2017 AND 2018
ORDER BY i.year ASC, i.month
-- FINDINGS:
-- YoY growth decelerates from +689% (Jan 2018) to +49% (Aug 2018).
-- This reflects market maturation, not decline — absolute revenue remains high.
-- September 2018 ($145, -99.98%) is a data artifact: dataset cuts off 2018-08-29.
-- Exclude Sep 2018 from any trend conclusions.



-- Top worst sellers acording to review scores

WITH info AS (
    SELECT
        ds.seller_id,
        COUNT(DISTINCT foi.order_id) AS total_orders,
        COUNT(DISTINCT fr.order_id) AS total_reviews,
        COUNT(DISTINCT fr.order_id) FILTER (WHERE fr.review_score BETWEEN 1 AND 2) AS total_bad_reviews,
        AVG(fr.review_score) AS avg_score,
        COUNT(DISTINCT fr.order_id) FILTER (WHERE fr.review_score BETWEEN 1 AND 2)::NUMERIC * 100 /
        NULLIF(COUNT(DISTINCT fr.order_id),0) AS pct_bad_reviews,
        SUM(foi.price) AS total_revenue
    FROM star.dim_seller ds 
    JOIN star.fact_order_items foi ON ds.seller_sk = foi.seller_sk
    JOIN star.fact_order_reviews fr ON fr.order_id = foi.order_id
    GROUP BY ds.seller_id
    HAVING COUNT(DISTINCT fr.order_id) >= 50
)
SELECT
    i.seller_id,
    i.total_orders,
    i.total_reviews,
    i.total_bad_reviews,
    ROUND(i.avg_score,2) AS avg_score,
    ROUND(i.pct_bad_reviews,2) AS pct_bad_reviews,
    i.total_revenue
FROM info i
ORDER BY pct_bad_reviews DESC, i.total_revenue DESC;


-- Average estimated time for deliveries by region, real vs estimated one

SELECT 
    dc.customer_region AS region,
    ROUND(AVG(estimated.full_date - purchase.full_date),2) AS estimated_delivery_time,
    ROUND(AVG(delivered.full_date - purchase.full_date),2) AS real_delivered_time,
    COUNT(fo.order_id) AS total_orders
FROM 
    star.fact_orders fo 
INNER JOIN star.dim_time purchase ON fo.purchase_date_sk = purchase.date_sk
INNER JOIN star.dim_time delivered ON fo.delivered_date_sk = delivered.date_sk
INNER JOIN star.dim_time estimated ON fo.estimated_delivery_sk = estimated.date_sk
INNER JOIN star.dim_customer dc ON fo.customer_sk = dc.customer_sk
GROUP BY dc.customer_region
-- FINDINGS:
-- All regions receive orders well ahead of estimated delivery date.
-- Olist deliberately overestimates delivery times as a buffer strategy.
-- Norte is the slowest region (22.54 days avg) but still arrives 15 days early.
-- Sudeste is fastest (10.69 days) — proximity to main distribution centers.
-- NOTE: only delivered orders included (INNER JOIN on delivered_date_sk
-- excludes NULLs automatically — canceled/pending orders not counted).


-- Distribution of payment methods and revenue by type.

SELECT
    payment_type,
    COUNT(order_id) AS total_orders,
    SUM(payment_value) AS total_revenue,
    ROUND((SUM(payment_value) / COUNT(order_id)),2) AS avg_ticket
FROM
    star.fact_order_payments
GROUP BY payment_type
ORDER BY total_revenue DESC;
-- FINDINGS:
-- Credit card dominates: 74% of transactions, highest avg ticket ($163).
-- Boleto (Brazilian bank slip) is second: 19% of transactions, $145 avg ticket.
-- Voucher has the lowest avg ticket ($65) — used for partial payments or discounts.
-- not_defined (3 transactions, $0.00): data quality issue in source.

---------------------------------------------------------------------------------------------

-- delivery_performance
-- Purpose : Build a delivery-performance dataset for the Tableau analysis,
-- resolving date surrogate keys from fact_orders into real dates
-- via role-playing joins on dim_time. Exported to CSV and consumed
-- by Tableau Public (which cannot connect live to PostgreSQL).
--
-- Grain : One row per DELIVERED order (orders never delivered are excluded
--           on purpose: an undelivered order has no delivery time to measure).
--
-- Notes : dim_time is joined three times (role-playing dimension), once per
-- date role: purchase, actual delivery, and estimated delivery.
-- A positive late_days value means the order arrived AFTER promised.

SELECT
    fo.order_id,
    fo.order_status,
    purchase_date.full_date      AS purchase_date,
    delivery_date.full_date      AS delivery_date,
    estimated_date.full_date     AS estimated_delivery_date,
    (delivery_date.full_date - purchase_date.full_date)   AS delivery_days,
    (delivery_date.full_date - estimated_date.full_date)  AS late_days,
    CASE WHEN (delivery_date.full_date - estimated_date.full_date) > 0 THEN TRUE
        ELSE FALSE
    END AS is_late
FROM star.fact_orders AS fo
    INNER JOIN star.dim_time AS purchase_date
        ON fo.purchase_date_sk = purchase_date.date_sk
    INNER JOIN star.dim_time AS delivery_date
        ON fo.delivered_date_sk = delivery_date.date_sk
    INNER JOIN star.dim_time AS estimated_date
        ON fo.estimated_delivery_sk = estimated_date.date_sk;
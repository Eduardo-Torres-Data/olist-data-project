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
select * from star.dim_seller limit 10
select * from star.fact_order_items limit 10
select * from star.fact_order_reviews limit 10

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

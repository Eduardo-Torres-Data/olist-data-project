-- File: 02-analytical-queries.sql
-- Module: 05 — Analytical Queries + Analyst Thinking
-- Dataset: Olist Brazilian E-Commerce (public schema, OLTP layer)

-- Business questions explored:
--   Q1. Customer distribution by state
--   Q2. Revenue and order volume by category
--   Q3. Sales trend: QoQ and YoY comparison
--   Q4. Order status distribution (completed vs canceled)
--   Q5. Product ratings by category

-- Postgres syntax introduced in this file:
--   DATE_TRUNC, EXTRACT, FILTER (WHERE),
--   window functions with date logic,
--   SUM() OVER () for inline percentage calculation

-----------------------------------------------------------------------------------

-- How many orders do we have per status and what is the percentage represented by each one

SELECT 
    order_status,
    COUNT(*) AS total_orders,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_of_total
FROM public.orders
GROUP BY order_status
ORDER BY total_orders DESC;

-- Which states buy the most? 
SELECT
    customer_state,
    COUNT(*) AS total_orders,
    COUNT(DISTINCT customer_unique_id) AS total_buyers,
    ROUND(COUNT(*) * 100.0/ SUM(COUNT(*)) OVER (), 2) AS pct_total_orders,
    ROUND(COUNT(DISTINCT customer_unique_id) * 100.0 / SUM(COUNT(DISTINCT customer_unique_id)) OVER (),2) AS pct_total_buyers
FROM public.customers
GROUP BY customer_state
ORDER BY total_orders DESC;

-- Revenue per category
SELECT
    COALESCE(p.product_category_name, 'Uncategorized') AS category,
    ROUND(SUM(o.price),2) AS total_revenue,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(o.price::NUMERIC) / NULLIF(COUNT(DISTINCT o.order_id),0),2) AS avg_ticket
FROM public.order_items o
LEFT JOIN public.products p ON o.product_id = p.product_id
GROUP BY p.product_category_name
ORDER BY avg_ticket DESC;

-- Data Engineering: Product Satisfaction Analysis
-- Objective: Identify low-quality categories with a minimum volume threshold.

WITH info_values AS (
    SELECT
        COALESCE(p.product_category_name, 'Uncategorized') AS category,
        COUNT(DISTINCT o.order_id) AS total_orders,
        COUNT(DISTINCT r.review_id) AS total_reviews,
        COUNT(DISTINCT r.review_id) FILTER (WHERE r.review_score BETWEEN 1 AND 2) AS bad_reviews,
        COUNT(DISTINCT r.review_id) FILTER (WHERE r.review_score BETWEEN 1 AND 2)::NUMERIC * 100 / 
        COUNT(DISTINCT r.review_id) AS pct_bad_reviews,
        SUM(o.price) AS total_revenue,
        SUM(o.price)::NUMERIC / NULLIF(COUNT(DISTINCT o.order_id),0) AS avg_ticket
    FROM public.order_items o
    LEFT JOIN public.products p ON o.product_id = p.product_id
    LEFT JOIN public.order_reviews r ON r.order_id = o.order_id
    GROUP BY COALESCE(p.product_category_name, 'Uncategorized')
)
SELECT 
    category,
    total_orders,
    total_reviews,
    bad_reviews,
    ROUND(pct_bad_reviews,2) AS pct_bad_reviews,
    ROUND(total_revenue,2) AS total_revenue,
    ROUND(avg_ticket,2) AS avg_ticket
FROM info_values
WHERE pct_bad_reviews > 20 AND total_reviews >= 50
ORDER BY pct_bad_reviews DESC, avg_ticket DESC;

-- FINDINGS: Product Satisfaction Analysis
-- Categories with >20% negative reviews (score 1-2) | min. 50 reviews

-- Priority ranking by business impact (not by bad review rate alone):
--
-- 1. moveis_escritorio — HIGHEST PRIORITY
--    22% bad reviews | 287 negative reviews | high revenue & avg ticket
--    Impact: largest absolute volume of dissatisfied customers in a
--    high-revenue category. Disproportionate contribution to platform-wide
--    dissatisfaction. Recommend: audit sellers in this category, apply
--    visibility restrictions or quality improvement requirements to
--    sellers exceeding a negative review threshold.
--
-- 2. audio — MEDIUM PRIORITY
--    22% bad reviews | 77 negative reviews | moderate volume
--    Recommend: seller-level review to identify repeat offenders.
--
-- 3. fashion_roupa_masculina — MONITOR
--    26% bad reviews | 29 negative reviews (lowest absolute volume)
--    High rate may reflect niche dissatisfaction rather than broad
--    product quality failure. Recommend: investigate review content
--    before escalating.
--
-- 4. construcao_ferramentas_seguranca — MONITOR
--    Sitting at the 20% threshold. Watch for trend changes.
--
-- DATA QUALITY NOTE — Uncategorized (20% bad reviews | 297 negative reviews)
--    These products lack a category assignment (FK orphans + NULL categories).
--    297 dissatisfied customers with no category visibility is a blind spot.
--    Recommend: classify these products before next review cycle.


-- Quarterly sales comparison (QoQ and YoY)
EXPLAIN ANALYZE
WITH info AS (SELECT 
    DATE_TRUNC('quarter', o.order_purchase_timestamp) AS quarter_start,
    EXTRACT(YEAR FROM o.order_purchase_timestamp) AS year,
    EXTRACT(quarter FROM o.order_purchase_timestamp) AS quarter,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(i.price) AS revenue
FROM public.orders o
INNER JOIN public.order_items i ON i.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY 1, 2, 3
)
SELECT 
    quarter_start,
    year,
    quarter,
    total_orders,
    ROUND(revenue,2) AS revenue,
    ROUND(((revenue - LAG(revenue, 1) OVER (ORDER BY quarter_start)) * 100.0)
    / NULLIF(LAG(revenue, 1) OVER (ORDER BY quarter_start), 0),2) AS pct_previous_quarter,
    ROUND((revenue - LAG(revenue, 4) OVER (ORDER BY quarter_start)) * 100.0
    / NULLIF(LAG(revenue, 4) OVER (ORDER BY quarter_start), 0),2) AS pct_previous_year
FROM info

SELECT 
    DATE_TRUNC('quarter', order_purchase_timestamp) AS quarter,
    MIN(order_purchase_timestamp) AS primera_orden,
    MAX(order_purchase_timestamp) AS ultima_orden
FROM public.orders
WHERE order_status = 'delivered'
GROUP BY 1
ORDER BY 1;

-- DATA COMPLETENESS NOTE:
-- Q3 2016: only 1 day of data (2016-09-15). Exclude from trend analysis.
-- Q3 2018: data cuts off on 2018-08-29 (2 of 3 months). The -39% QoQ
-- is a data artifact, not a real business decline. YoY (+3.82%) is also
-- understated. Trend conclusions should be based on Q1-Q2 2018 only.
-- Real finding: growth deceleration from +77% QoQ (Q3 2017) to +3.8% (Q2 2018).

EXPLAIN ANALYZE
SELECT order_status, COUNT(*) 
FROM public.orders 
GROUP BY order_status;
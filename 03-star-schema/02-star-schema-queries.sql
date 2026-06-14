-- Olist Brazilian E-Commerce · Star Schema Analytical Queries

-- Description:
--   Analytical queries built on top of the star schema (star.*).
--   Demonstrates dimensional modeling patterns: role-playing dimensions,
--   degenerate dimension grouping, and cross-fact joins via shared keys.

-- Total revenue and orders per customer region




SELECT *
FROM star.dim_customer LIMIT 10

SELECT * 
FROM star.fact_orders LIMIT 10
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

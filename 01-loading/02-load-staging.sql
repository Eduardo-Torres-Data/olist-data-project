-- Run from the project root with the nine Olist CSV files in data/.
BEGIN;

\ir 01-create-tables.sql

CREATE SCHEMA staging;
ALTER TABLE public.customers SET SCHEMA staging;
ALTER TABLE public.geolocation SET SCHEMA staging;
ALTER TABLE public.order_items SET SCHEMA staging;
ALTER TABLE public.order_payments SET SCHEMA staging;
ALTER TABLE public.order_reviews SET SCHEMA staging;
ALTER TABLE public.orders SET SCHEMA staging;
ALTER TABLE public.product_category_name_translation SET SCHEMA staging;
ALTER TABLE public.products SET SCHEMA staging;
ALTER TABLE public.sellers SET SCHEMA staging;

\copy staging.customers FROM 'data/olist_customers_dataset.csv' WITH (FORMAT csv, HEADER true)
\copy staging.geolocation FROM 'data/olist_geolocation_dataset.csv' WITH (FORMAT csv, HEADER true)
\copy staging.order_items FROM 'data/olist_order_items_dataset.csv' WITH (FORMAT csv, HEADER true)
\copy staging.order_payments FROM 'data/olist_order_payments_dataset.csv' WITH (FORMAT csv, HEADER true)
\copy staging.order_reviews FROM 'data/olist_order_reviews_dataset.csv' WITH (FORMAT csv, HEADER true)
\copy staging.orders FROM 'data/olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true)
\copy staging.product_category_name_translation FROM 'data/product_category_name_translation.csv' WITH (FORMAT csv, HEADER true)
\copy staging.products FROM 'data/olist_products_dataset.csv' WITH (FORMAT csv, HEADER true)
\copy staging.sellers FROM 'data/olist_sellers_dataset.csv' WITH (FORMAT csv, HEADER true)

COMMIT;

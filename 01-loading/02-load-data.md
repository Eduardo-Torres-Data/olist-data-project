# Data Loading

Source: [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

## Prerequisites
1. PostgreSQL running locally
2. Database `olist_sales` created
3. Tables created by running `01-create-tables.sql`
4. CSV files downloaded from Kaggle (not included in repo)

## Loading the data

From psql, run:

```sql
\copy customers FROM '/path/to/olist_customers_dataset.csv' DELIMITER ',' CSV HEADER;
\copy orders FROM '/path/to/olist_orders_dataset.csv' DELIMITER ',' CSV HEADER;
\copy order_items FROM '/path/to/olist_order_items_dataset.csv' DELIMITER ',' CSV HEADER;
\copy sellers FROM '/path/to/olist_sellers_dataset.csv' DELIMITER ',' CSV HEADER;
\copy products FROM '/path/to/olist_products_dataset.csv' DELIMITER ',' CSV HEADER;
\copy order_payments FROM '/path/to/olist_order_payments_dataset.csv' DELIMITER ',' CSV HEADER;
\copy order_reviews FROM '/path/to/olist_order_reviews_dataset.csv' DELIMITER ',' CSV HEADER;
\copy geolocation FROM '/path/to/olist_geolocation_dataset.csv' DELIMITER ',' CSV HEADER;
\copy product_category_name_translation FROM '/path/to/product_category_name_translation.csv' DELIMITER ',' CSV HEADER;
```
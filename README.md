# Olist e-commerce analysis

I used PostgreSQL and Tableau to explore order volume, sales by category, delivery times and customer reviews in the [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce). The source covers roughly 100,000 orders from 2016 to 2018.

The SQL loads the CSV files into `staging`, cleans and validates them in `public`, then builds a star schema for reporting. Orders, items, payments and reviews each have their own fact table, so reports can use the level of detail appropriate to the question.

## Where to start

- [Analytical SQL](02-queries/02-analytical-queries.sql) for order status, sales trends and categories.
- [Star schema and queries](03-star-schema) for dimensional modeling, payment mix and delivery performance by region.
- [Tableau workbook](04-tableau/olist_dashboard_FINAL.twb) for sales, logistics and reviews.
- [Python notebooks](05-python/notebooks) for the separate Python practice exercises.

## Run locally

Use PostgreSQL 17 with an up-to-date `psql` client. Download the dataset and put the nine CSV files in a `data` folder at the root. Run these commands from the repository in a new database.

```sh
createdb olist_demo
psql -X -v ON_ERROR_STOP=1 -d olist_demo \
  -f 01-loading/02-load-staging.sql \
  -f 01-loading/03-create-oltp-tables.sql \
  -f 01-loading/04-etl-staging-to-oltp.sql \
  -f 03-star-schema/01-create-table-olap.sql \
  -f 03-star-schema/02-etl-oltp-to-olap.sql
psql -X -v ON_ERROR_STOP=1 -d olist_demo -f 03-star-schema/03-star-schema-queries.sql
```

To open the Tableau workbook, export the star tables it uses to CSV with column headers and reconnect its text data source to that folder. The workbook uses `fact_order_items`, `fact_orders`, `fact_order_reviews`, `dim_customer`, `dim_product`, `dim_seller` and `dim_time`.

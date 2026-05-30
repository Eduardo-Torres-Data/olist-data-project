--
-- PostgreSQL database dump
--

\restrict CB4Xu963HMb9GbATfaeeLxd2uJifpVvzkeY27ko0QV9DdCIYbuJ7ehzZtrUV9dj

-- Dumped from database version 17.10 (Homebrew)
-- Dumped by pg_dump version 17.10 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: customers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customers (
    customer_id character varying(50) NOT NULL,
    customer_unique_id character varying(50),
    customer_zip_code_prefix integer,
    customer_city character varying(100),
    customer_state character varying(10)
);


--
-- Name: geolocation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.geolocation (
    geolocation_zip_code_prefix character varying,
    geolocation_lat character varying,
    geolocation_lng character varying,
    geolocation_city character varying,
    geolocation_state character varying
);


--
-- Name: order_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_items (
    order_id character varying(50) NOT NULL,
    order_item_id integer NOT NULL,
    product_id character varying(50),
    seller_id character varying(50),
    shipping_limit_date character varying(30),
    price double precision,
    freight_value double precision
);


--
-- Name: order_payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_payments (
    order_id character varying,
    payment_sequential character varying,
    payment_type character varying,
    payment_installments character varying,
    payment_value character varying
);


--
-- Name: order_reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_reviews (
    review_id character varying,
    order_id character varying,
    review_score character varying,
    review_comment_title character varying,
    review_comment_message character varying,
    review_creation_date character varying,
    review_answer_timestamp character varying
);


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    order_id character varying(50) NOT NULL,
    customer_id character varying(50),
    order_status character varying(30),
    order_purchase_date timestamp without time zone,
    order_approved_date timestamp without time zone,
    order_delivered_carrier_date_real timestamp without time zone,
    order_delivered_customer_date_real timestamp without time zone,
    order_estimated_delivery_date_real timestamp without time zone
);


--
-- Name: product_category_name_translation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_category_name_translation (
    product_category_name character varying,
    product_category_name_english character varying
);


--
-- Name: products; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.products (
    product_id character varying,
    product_category_name character varying,
    product_name_lenght character varying,
    product_description_lenght character varying,
    product_photos_qty character varying,
    product_weight_g character varying,
    product_length_cm character varying,
    product_height_cm character varying,
    product_width_cm character varying
);


--
-- Name: sellers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sellers (
    seller_id character varying,
    seller_zip_code_prefix character varying,
    seller_city character varying,
    seller_state character varying
);


--
-- Name: customers customers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customers
    ADD CONSTRAINT customers_pkey PRIMARY KEY (customer_id);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (order_id, order_item_id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (order_id);


--
-- PostgreSQL database dump complete
--

\unrestrict CB4Xu963HMb9GbATfaeeLxd2uJifpVvzkeY27ko0QV9DdCIYbuJ7ehzZtrUV9dj


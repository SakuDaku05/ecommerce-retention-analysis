-- 01_prepare.sql
-- Goal: turn the raw Online Retail transactions into clean, analysis-ready tables.
-- Run order: this file first (run_analysis.py does it for you).

DROP TABLE IF EXISTS purchases CASCADE;
DROP TABLE IF EXISTS clean_transactions CASCADE;

-- 1) Clean line items
--    * drop rows with no customer (we cannot follow a journey without an id)
--    * drop cancellations (invoice numbers starting with 'C')
--    * drop non-positive quantity / price (returns, adjustments, test rows)
--    * DISTINCT removes exact duplicate lines
CREATE TABLE clean_transactions AS
SELECT DISTINCT
    invoice_no,
    stock_code,
    description,
    quantity,
    invoice_date,
    unit_price,
    customer_id::int      AS customer_id,
    country,
    quantity * unit_price AS line_revenue
FROM raw_online_retail
WHERE customer_id IS NOT NULL
  AND invoice_no NOT LIKE 'C%'
  AND quantity   > 0
  AND unit_price > 0;

-- 2) One row per customer per purchase DAY ("a purchase occasion").
--    Several invoices on the same day count as one purchase, so a second
--    invoice an hour later is not mistaken for a "repeat purchase".
CREATE TABLE purchases AS
SELECT
    customer_id,
    invoice_date::date          AS purchase_date,
    COUNT(DISTINCT invoice_no)  AS invoices,
    SUM(line_revenue)           AS purchase_value,
    MIN(country)                AS country
FROM clean_transactions
GROUP BY customer_id, invoice_date::date;

CREATE INDEX idx_purchases_customer ON purchases (customer_id, purchase_date);

-- 3) Window functions: number each customer's purchases and look at neighbours
--    ROW_NUMBER -> which purchase is this (1st, 2nd, ...)
--    LAG / LEAD -> previous / next purchase date for the same customer
CREATE OR REPLACE VIEW customer_purchases AS
SELECT
    customer_id,
    purchase_date,
    purchase_value,
    country,
    ROW_NUMBER() OVER w                               AS purchase_seq,
    LAG(purchase_date)  OVER w                        AS prev_purchase_date,
    LEAD(purchase_date) OVER w                        AS next_purchase_date,
    purchase_date - LAG(purchase_date) OVER w         AS days_since_prev
FROM purchases
WINDOW w AS (PARTITION BY customer_id ORDER BY purchase_date);

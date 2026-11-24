-- 04_return_rates_30_60_90.sql
-- Share of customers who buy again within 30 / 60 / 90 days of their first purchase.
-- Fairness rule: a customer only counts for the 90-day rate if we have watched them for at
-- least 90 days (first purchase <= last date in the data - 90). Same for 30 and 60.
-- Skills: self-join, date arithmetic, FILTER, avoiding "right-censoring" bias.

WITH bounds AS (
    SELECT MAX(purchase_date) AS last_date FROM purchases
),
first_purchase AS (
    SELECT customer_id, MIN(purchase_date) AS first_date
    FROM purchases
    GROUP BY customer_id
),
returns AS (
    SELECT
        f.customer_id,
        f.first_date,
        BOOL_OR(p.purchase_date BETWEEN f.first_date + 1 AND f.first_date + 30) AS r30,
        BOOL_OR(p.purchase_date BETWEEN f.first_date + 1 AND f.first_date + 60) AS r60,
        BOOL_OR(p.purchase_date BETWEEN f.first_date + 1 AND f.first_date + 90) AS r90
    FROM first_purchase f
    LEFT JOIN purchases p ON p.customer_id = f.customer_id
    GROUP BY f.customer_id, f.first_date
)
SELECT
    date_trunc('month', first_date)::date AS cohort_month,
    COUNT(*)                               AS cohort_customers,
    ROUND(100.0 * AVG(COALESCE(r30, false)::int) FILTER (WHERE first_date <= (SELECT last_date FROM bounds) - 30), 1) AS return_30d_pct,
    ROUND(100.0 * AVG(COALESCE(r60, false)::int) FILTER (WHERE first_date <= (SELECT last_date FROM bounds) - 60), 1) AS return_60d_pct,
    ROUND(100.0 * AVG(COALESCE(r90, false)::int) FILTER (WHERE first_date <= (SELECT last_date FROM bounds) - 90), 1) AS return_90d_pct
FROM returns
GROUP BY 1
ORDER BY 1;

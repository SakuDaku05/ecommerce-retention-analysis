-- 03_cohort_retention.sql
-- Monthly cohorts: group customers by the month of their FIRST purchase, then see what share
-- of each cohort buys again 1, 2, 3 ... months later.
-- Skills: CTEs, date_trunc, joins, retention = active customers / cohort size.

WITH first_purchase AS (
    SELECT customer_id, date_trunc('month', MIN(purchase_date))::date AS cohort_month
    FROM purchases
    GROUP BY customer_id
),
activity AS (
    SELECT
        f.cohort_month,
        (EXTRACT(YEAR  FROM date_trunc('month', p.purchase_date)) - EXTRACT(YEAR  FROM f.cohort_month)) * 12
      + (EXTRACT(MONTH FROM date_trunc('month', p.purchase_date)) - EXTRACT(MONTH FROM f.cohort_month)) AS month_index,
        p.customer_id
    FROM purchases p
    JOIN first_purchase f USING (customer_id)
),
cohort_size AS (
    SELECT cohort_month, COUNT(*) AS cohort_customers
    FROM first_purchase
    GROUP BY cohort_month
)
SELECT
    a.cohort_month,
    c.cohort_customers,
    a.month_index::int                                              AS month_index,
    COUNT(DISTINCT a.customer_id)                                   AS active_customers,
    ROUND(100.0 * COUNT(DISTINCT a.customer_id) / c.cohort_customers, 1) AS retention_pct
FROM activity a
JOIN cohort_size c USING (cohort_month)
GROUP BY a.cohort_month, c.cohort_customers, a.month_index
ORDER BY a.cohort_month, a.month_index;

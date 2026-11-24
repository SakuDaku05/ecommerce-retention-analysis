-- 05_segment_comparison.sql
-- Does the kind of customer we acquire change how likely they are to come back?
-- Segment A: first-purchase value quartile (NTILE)    -> "big first basket" vs "small first basket"
-- Segment B: UK vs rest of world                      -> acquisition market
-- Measure: 90-day return rate (only customers observed for >= 90 days).
-- Skills: NTILE, UNION ALL, window functions, fair cohort windows.

WITH bounds AS (
    SELECT MAX(purchase_date) AS last_date FROM purchases
),
first_purchase AS (
    SELECT customer_id, purchase_date AS first_date, purchase_value AS first_value, country
    FROM customer_purchases
    WHERE purchase_seq = 1
),
scored AS (
    SELECT
        f.*,
        NTILE(4) OVER (ORDER BY first_value) AS value_quartile,
        EXISTS (
            SELECT 1 FROM purchases p
            WHERE p.customer_id = f.customer_id
              AND p.purchase_date BETWEEN f.first_date + 1 AND f.first_date + 90
        ) AS returned_90d
    FROM first_purchase f
),
eligible AS (
    SELECT * FROM scored WHERE first_date <= (SELECT last_date FROM bounds) - 90
)
SELECT 'first purchase value quartile' AS segment_type,
       CASE value_quartile WHEN 1 THEN 'Q1 (lowest first basket)'
                           WHEN 2 THEN 'Q2'
                           WHEN 3 THEN 'Q3'
                           ELSE 'Q4 (highest first basket)' END AS segment,
       COUNT(*) AS customers,
       ROUND(100.0 * AVG(returned_90d::int), 1) AS return_90d_pct
FROM eligible
GROUP BY value_quartile
UNION ALL
SELECT 'acquisition market',
       CASE WHEN country = 'United Kingdom' THEN 'United Kingdom' ELSE 'Rest of world' END,
       COUNT(*),
       ROUND(100.0 * AVG(returned_90d::int), 1)
FROM eligible
GROUP BY CASE WHEN country = 'United Kingdom' THEN 'United Kingdom' ELSE 'Rest of world' END
ORDER BY segment_type, segment;

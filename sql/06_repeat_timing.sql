-- 06_repeat_timing.sql
-- How long do customers wait between purchases, and how many purchases are followed by another one?
-- Uses the window-function columns built in the customer_purchases view (01_prepare.sql):
--   days_since_prev     (built with LAG)  -> days since the customer's previous purchase
--   next_purchase_date  (built with LEAD) -> date of the customer's next purchase (NULL if none)
-- Fairness rule: "followed within 90 days" only counts purchases made at least 90 days before the data ends,
-- so every purchase had a full 90 days in which a next purchase could happen.
-- Skills: LAG and LEAD in practice, PERCENTILE_CONT, FILTER, fair observation windows.
WITH bounds AS (
    SELECT MAX(purchase_date) AS last_date FROM purchases
)
SELECT
    LEAST(purchase_seq, 6)                                                            AS purchase_number,
    CASE WHEN purchase_seq >= 6 THEN '6th+' ELSE purchase_seq::text END                AS label,
    COUNT(*)                                                                          AS purchases,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_since_prev))::numeric, 0) AS median_days_since_previous,
    ROUND((PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY days_since_prev))::numeric, 0) AS p90_days_since_previous,
    ROUND(100.0 * AVG((next_purchase_date IS NOT NULL
                       AND next_purchase_date - purchase_date <= 90)::int)
          FILTER (WHERE purchase_date <= (SELECT last_date FROM bounds) - 90), 1)     AS pct_followed_within_90d
FROM customer_purchases
GROUP BY LEAST(purchase_seq, 6), CASE WHEN purchase_seq >= 6 THEN '6th+' ELSE purchase_seq::text END
ORDER BY purchase_number;

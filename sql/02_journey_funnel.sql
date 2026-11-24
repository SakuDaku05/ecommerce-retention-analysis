-- 02_journey_funnel.sql
-- Question: of the customers we acquired, how many come back for a 2nd, 3rd ... purchase,
-- and which step loses the most people?
-- Skills: ROW_NUMBER (via the view), conditional counting, LAG, FIRST_VALUE.

WITH per_customer AS (
    SELECT customer_id, MAX(purchase_seq) AS n_purchases
    FROM customer_purchases
    GROUP BY customer_id
),
stages AS (
    SELECT
        k                                                AS stage,
        COUNT(*) FILTER (WHERE n_purchases >= k)         AS customers_reached
    FROM per_customer
    CROSS JOIN generate_series(1, 6) AS k
    GROUP BY k
)
SELECT
    stage,
    CASE WHEN stage = 6 THEN '6th+ purchase'
         ELSE stage || CASE stage WHEN 1 THEN 'st' WHEN 2 THEN 'nd' WHEN 3 THEN 'rd' ELSE 'th' END || ' purchase'
    END                                                                       AS stage_name,
    customers_reached,
    ROUND(100.0 * customers_reached / FIRST_VALUE(customers_reached) OVER (ORDER BY stage), 1) AS pct_of_acquired,
    ROUND(100.0 * customers_reached / LAG(customers_reached) OVER (ORDER BY stage), 1)         AS step_conversion_pct,
    ROUND(100.0 - 100.0 * customers_reached / LAG(customers_reached) OVER (ORDER BY stage), 1) AS step_dropoff_pct
FROM stages
ORDER BY stage;

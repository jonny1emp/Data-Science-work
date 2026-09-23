Project: Customer Cohort Analysis template
Goal: Calculate month-over-month retention rates for new customer cohorts.
Database: PostgreSQL / Snowflake / BigQuery

 Identify the first (cohort) for each customer
WITH customer_cohorts AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(order_date)) AS cohort_month
    FROM raw_orders
    WHERE order_status = 'Completed'
    GROUP BY customer_id
),

 Aggregate monthly activity and map it back to the user's baseline cohort
order_activity AS (
    SELECT 
        c.cohort_month,
        DATE_TRUNC('month', o.order_date) AS order_month,
        COUNT(DISTINCT o.customer_id) AS active_customers,
        SUM(o.revenue) AS total_revenue
    FROM customer_cohorts c
    JOIN raw_orders o 
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'Completed'
    GROUP BY 1, 2
),

 retention metrics Functions
retention_metrics AS (
    SELECT 
        cohort_month,
        order_month,
        active_customers,
        total_revenue,
        -- Months since cohort acquisition (0 = acquisition month)
        EXTRACT(MONTH FROM AGE(order_month, cohort_month)) AS months_since_acquisition,
        
        -- Calculate retention rate: active customers / original cohort size
        ROUND(
            active_customers::NUMERIC / 
            FIRST_VALUE(active_customers) OVER (
                PARTITION BY cohort_month 
                ORDER BY order_month ASC
            ) * 100, 
            2
        ) AS retention_rate_pct
        
    FROM order_activity
)

 Final output formatted for the BI dashboard
SELECT 
    cohort_month,
    months_since_acquisition,
    active_customers,
    total_revenue,
    retention_rate_pct,
    -- Data quality check: flag if revenue is null
    COALESCE(total_revenue, 0) AS cleaned_revenue
FROM retention_metrics
WHERE months_since_acquisition <= 6 -- Limit to first 6 months for readability
ORDER BY cohort_month DESC, months_since_acquisition ASC;

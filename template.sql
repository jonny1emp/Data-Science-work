Project: Customer Cohort Analysis template
Goal: Calculate month-over-month retention rates for new customer cohorts.
Database: PostgreSQL / Snowflake / BigQuery

CREATE TABLE raw_orders (
    order_id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    order_date DATE NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    revenue NUMERIC(10,2) NOT NULL
);

INSERT INTO raw_orders (
    order_id,
    customer_id,
    order_date,
    order_status,
    revenue
)
VALUES
    (1, 101, '2026-01-05', 'Completed', 120.00),
    (2, 102, '2026-01-08', 'Completed', 200.00),
    (3, 103, '2026-01-15', 'Completed', 150.00),
    (4, 104, '2026-01-20', 'Completed', 300.00),
    (5, 101, '2026-02-03', 'Completed', 100.00),
    (6, 103, '2026-02-10', 'Completed', 180.00),
    (7, 104, '2026-02-18', 'Completed', 250.00),
    (8, 101, '2026-03-04', 'Completed', 140.00),
    (9, 104, '2026-03-12', 'Completed', 220.00),
    (10, 101, '2026-04-05', 'Completed', 160.00),
    (11, 105, '2026-02-05', 'Completed', 100.00),
    (12, 106, '2026-02-12', 'Completed', 250.00),
    (13, 107, '2026-02-20', 'Completed', 175.00),
    (14, 105, '2026-03-05', 'Completed', 120.00),
    (15, 107, '2026-03-15', 'Completed', 200.00),
    (16, 105, '2026-04-10', 'Completed', 150.00),
    (17, 108, '2026-03-03', 'Completed', 300.00),
    (18, 109, '2026-03-10', 'Completed', 125.00),
    (19, 110, '2026-03-22', 'Completed', 180.00),
    (20, 108, '2026-04-05', 'Completed', 250.00),
    (21, 110, '2026-04-18', 'Completed', 160.00),
    (22, 111, '2026-04-02', 'Completed', 200.00),
    (23, 112, '2026-04-12', 'Completed', 150.00),
    (24, 113, '2026-04-15', 'Cancelled', 500.00);

WITH customer_cohorts AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(order_date))::DATE AS cohort_month
    FROM raw_orders
    WHERE order_status = 'Completed'
    GROUP BY customer_id
),

order_activity AS (
    SELECT
        c.cohort_month,
        DATE_TRUNC('month', o.order_date)::DATE AS order_month,
        COUNT(DISTINCT o.customer_id) AS active_customers,
        SUM(o.revenue) AS total_revenue
    FROM customer_cohorts c
    JOIN raw_orders o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'Completed'
    GROUP BY
        c.cohort_month,
        DATE_TRUNC('month', o.order_date)
),

retention_metrics AS (
    SELECT
        cohort_month,
        order_month,
        active_customers,
        total_revenue,
        (
            EXTRACT(YEAR FROM order_month) * 12
            + EXTRACT(MONTH FROM order_month)
        ) - (
            EXTRACT(YEAR FROM cohort_month) * 12
            + EXTRACT(MONTH FROM cohort_month)
        ) AS months_since_acquisition,
        ROUND(
            active_customers::NUMERIC
            / FIRST_VALUE(active_customers) OVER (
                PARTITION BY cohort_month
                ORDER BY order_month
            ) * 100,
            2
        ) AS retention_rate_pct
    FROM order_activity
)

SELECT
    cohort_month,
    months_since_acquisition,
    active_customers,
    total_revenue,
    retention_rate_pct,
    COALESCE(total_revenue, 0) AS cleaned_revenue
FROM retention_metrics
WHERE months_since_acquisition <= 6
ORDER BY
    cohort_month DESC,
    months_since_acquisition ASC;

-- ============================================================
-- Retail Demand Forecasting & Inventory Optimization
-- SQL Analytics Layer — 30+ KPI Queries
-- Database: retail_forecasting (PostgreSQL)
-- ============================================================
-- Run against: vw_daily_sales_with_revenue (denormalized view)
-- ============================================================


-- ============================================================
-- SECTION 1: CORE KPIs
-- ============================================================

-- KPI 1: Total Sales & Revenue (All Time)
SELECT
    COUNT(*)                            AS total_transactions,
    SUM(units_sold)                     AS total_units_sold,
    ROUND(SUM(revenue)::NUMERIC, 2)     AS total_revenue,
    ROUND(AVG(sell_price)::NUMERIC, 2)  AS avg_sell_price,
    MIN(date)                           AS data_start_date,
    MAX(date)                           AS data_end_date
FROM vw_daily_sales_with_revenue
WHERE units_sold > 0;


-- KPI 2: Monthly Revenue Trend
SELECT
    year,
    month,
    TO_CHAR(MIN(date), 'Mon YYYY')      AS month_label,
    SUM(units_sold)                     AS total_units,
    ROUND(SUM(revenue)::NUMERIC, 2)     AS monthly_revenue,
    ROUND(AVG(sell_price)::NUMERIC, 2)  AS avg_price
FROM vw_daily_sales_with_revenue
GROUP BY year, month
ORDER BY year, month;


-- KPI 3: Year-over-Year Revenue Growth
WITH yearly_revenue AS (
    SELECT
        year,
        ROUND(SUM(revenue)::NUMERIC, 2) AS revenue
    FROM vw_daily_sales_with_revenue
    GROUP BY year
)
SELECT
    year,
    revenue,
    LAG(revenue) OVER (ORDER BY year)              AS prev_year_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY year)) /
        NULLIF(LAG(revenue) OVER (ORDER BY year), 0) * 100,
        2
    )                                               AS yoy_growth_pct
FROM yearly_revenue
ORDER BY year;


-- KPI 4: Weekly Sales (Last 12 Weeks)
SELECT
    dc.wm_yr_wk,
    MIN(fs.date)                        AS week_start_date,
    SUM(fs.units_sold)                  AS total_units,
    ROUND(SUM(fs.units_sold * fp.sell_price)::NUMERIC, 2) AS weekly_revenue
FROM fact_sales fs
JOIN dim_calendar dc ON fs.date = dc.date
LEFT JOIN fact_prices fp
    ON fs.store_id = fp.store_id
    AND fs.product_id = fp.product_id
    AND fp.wm_yr_wk = dc.wm_yr_wk
WHERE fs.date >= (SELECT MAX(date) - INTERVAL '84 days' FROM fact_sales)
GROUP BY dc.wm_yr_wk
ORDER BY dc.wm_yr_wk;


-- ============================================================
-- SECTION 2: PRODUCT ANALYSIS
-- ============================================================

-- KPI 5: Top 20 Products by Total Units Sold
SELECT
    fs.product_id,
    dp.dept_id,
    dp.cat_id,
    SUM(fs.units_sold)                  AS total_units_sold,
    ROUND(SUM(fs.units_sold * fp.sell_price)::NUMERIC, 2) AS total_revenue,
    COUNT(DISTINCT fs.store_id)         AS stores_selling
FROM fact_sales fs
JOIN dim_product dp ON fs.product_id = dp.product_id
LEFT JOIN fact_prices fp
    ON fs.store_id = fp.store_id
    AND fs.product_id = fp.product_id
    AND fp.wm_yr_wk = (SELECT wm_yr_wk FROM dim_calendar WHERE date = fs.date)
GROUP BY fs.product_id, dp.dept_id, dp.cat_id
ORDER BY total_units_sold DESC
LIMIT 20;


-- KPI 6: Top 20 Products by Revenue
SELECT
    fs.product_id,
    dp.cat_id,
    dp.dept_id,
    ROUND(SUM(fs.units_sold * fp.sell_price)::NUMERIC, 2) AS total_revenue,
    SUM(fs.units_sold)                  AS total_units,
    ROUND(AVG(fp.sell_price)::NUMERIC, 2) AS avg_price
FROM fact_sales fs
JOIN dim_product dp ON fs.product_id = dp.product_id
JOIN fact_prices fp
    ON fs.store_id = fp.store_id
    AND fs.product_id = fp.product_id
    AND fp.wm_yr_wk = (SELECT wm_yr_wk FROM dim_calendar WHERE date = fs.date)
WHERE fs.units_sold > 0
GROUP BY fs.product_id, dp.cat_id, dp.dept_id
ORDER BY total_revenue DESC
LIMIT 20;


-- KPI 7: Worst-Performing Products (Bottom 20 by Revenue)
SELECT
    fs.product_id,
    dp.cat_id,
    ROUND(SUM(fs.units_sold * fp.sell_price)::NUMERIC, 2) AS total_revenue,
    SUM(fs.units_sold)                  AS total_units,
    COUNT(DISTINCT fs.date)             AS days_with_sales
FROM fact_sales fs
JOIN dim_product dp ON fs.product_id = dp.product_id
JOIN fact_prices fp
    ON fs.store_id = fp.store_id
    AND fs.product_id = fp.product_id
    AND fp.wm_yr_wk = (SELECT wm_yr_wk FROM dim_calendar WHERE date = fs.date)
GROUP BY fs.product_id, dp.cat_id
HAVING SUM(fs.units_sold) > 0
ORDER BY total_revenue ASC
LIMIT 20;


-- ============================================================
-- SECTION 3: CATEGORY ANALYSIS
-- ============================================================

-- KPI 8: Revenue by Category
SELECT
    dp.cat_id,
    SUM(fs.units_sold)                  AS total_units,
    ROUND(SUM(fs.units_sold * fp.sell_price)::NUMERIC, 2) AS total_revenue,
    ROUND(
        SUM(fs.units_sold * fp.sell_price) /
        SUM(SUM(fs.units_sold * fp.sell_price)) OVER () * 100,
        2
    )                                   AS revenue_share_pct,
    COUNT(DISTINCT fs.product_id)       AS unique_products
FROM fact_sales fs
JOIN dim_product dp ON fs.product_id = dp.product_id
JOIN fact_prices fp
    ON fs.store_id = fp.store_id
    AND fs.product_id = fp.product_id
    AND fp.wm_yr_wk = (SELECT wm_yr_wk FROM dim_calendar WHERE date = fs.date)
WHERE fs.units_sold > 0
GROUP BY dp.cat_id
ORDER BY total_revenue DESC;


-- KPI 9: Department Revenue Breakdown
SELECT
    dp.cat_id,
    dp.dept_id,
    SUM(fs.units_sold)                  AS total_units,
    ROUND(SUM(fs.units_sold * fp.sell_price)::NUMERIC, 2) AS total_revenue
FROM fact_sales fs
JOIN dim_product dp ON fs.product_id = dp.product_id
JOIN fact_prices fp
    ON fs.store_id = fp.store_id
    AND fs.product_id = fp.product_id
    AND fp.wm_yr_wk = (SELECT wm_yr_wk FROM dim_calendar WHERE date = fs.date)
WHERE fs.units_sold > 0
GROUP BY dp.cat_id, dp.dept_id
ORDER BY dp.cat_id, total_revenue DESC;


-- KPI 10: Monthly Category Trend
SELECT
    dc.year,
    dc.month,
    dp.cat_id,
    SUM(fs.units_sold)                  AS total_units
FROM fact_sales fs
JOIN dim_calendar dc ON fs.date = dc.date
JOIN dim_product dp ON fs.product_id = dp.product_id
GROUP BY dc.year, dc.month, dp.cat_id
ORDER BY dc.year, dc.month, dp.cat_id;


-- ============================================================
-- SECTION 4: STORE ANALYSIS
-- ============================================================

-- KPI 11: Revenue by Store
SELECT
    fs.store_id,
    ds.state_id,
    SUM(fs.units_sold)                  AS total_units,
    ROUND(SUM(fs.units_sold * fp.sell_price)::NUMERIC, 2) AS total_revenue,
    ROUND(
        SUM(fs.units_sold * fp.sell_price) /
        SUM(SUM(fs.units_sold * fp.sell_price)) OVER () * 100,
        2
    )                                   AS store_revenue_share_pct,
    COUNT(DISTINCT fs.product_id)       AS active_skus
FROM fact_sales fs
JOIN dim_store ds ON fs.store_id = ds.store_id
JOIN fact_prices fp
    ON fs.store_id = fp.store_id
    AND fs.product_id = fp.product_id
    AND fp.wm_yr_wk = (SELECT wm_yr_wk FROM dim_calendar WHERE date = fs.date)
WHERE fs.units_sold > 0
GROUP BY fs.store_id, ds.state_id
ORDER BY total_revenue DESC;


-- KPI 12: Revenue by State
SELECT
    ds.state_id,
    COUNT(DISTINCT fs.store_id)         AS num_stores,
    SUM(fs.units_sold)                  AS total_units,
    ROUND(SUM(fs.units_sold * fp.sell_price)::NUMERIC, 2) AS total_revenue
FROM fact_sales fs
JOIN dim_store ds ON fs.store_id = ds.store_id
JOIN fact_prices fp
    ON fs.store_id = fp.store_id
    AND fs.product_id = fp.product_id
    AND fp.wm_yr_wk = (SELECT wm_yr_wk FROM dim_calendar WHERE date = fs.date)
WHERE fs.units_sold > 0
GROUP BY ds.state_id
ORDER BY total_revenue DESC;


-- KPI 13: Store Performance Ranking (with window functions)
WITH store_revenue AS (
    SELECT
        fs.store_id,
        ds.state_id,
        ROUND(SUM(fs.units_sold * fp.sell_price)::NUMERIC, 2) AS total_revenue
    FROM fact_sales fs
    JOIN dim_store ds ON fs.store_id = ds.store_id
    JOIN fact_prices fp
        ON fs.store_id = fp.store_id
        AND fs.product_id = fp.product_id
        AND fp.wm_yr_wk = (SELECT wm_yr_wk FROM dim_calendar WHERE date = fs.date)
    WHERE fs.units_sold > 0
    GROUP BY fs.store_id, ds.state_id
)
SELECT
    store_id,
    state_id,
    total_revenue,
    RANK() OVER (ORDER BY total_revenue DESC)          AS revenue_rank,
    RANK() OVER (PARTITION BY state_id ORDER BY total_revenue DESC) AS rank_within_state
FROM store_revenue
ORDER BY revenue_rank;


-- ============================================================
-- SECTION 5: SEASONALITY ANALYSIS
-- ============================================================

-- KPI 14: Sales by Day of Week
SELECT
    dc.weekday,
    dc.wday,
    ROUND(AVG(daily.daily_units), 2)    AS avg_daily_units,
    ROUND(AVG(daily.daily_revenue), 2)  AS avg_daily_revenue
FROM (
    SELECT
        fs.date,
        SUM(fs.units_sold)                          AS daily_units,
        SUM(fs.units_sold * fp.sell_price)          AS daily_revenue
    FROM fact_sales fs
    JOIN fact_prices fp
        ON fs.store_id = fp.store_id
        AND fs.product_id = fp.product_id
        AND fp.wm_yr_wk = (SELECT wm_yr_wk FROM dim_calendar WHERE date = fs.date)
    GROUP BY fs.date
) daily
JOIN dim_calendar dc ON daily.date = dc.date
GROUP BY dc.weekday, dc.wday
ORDER BY dc.wday;


-- KPI 15: Monthly Seasonality (Average Monthly Units by Year)
SELECT
    dc.month,
    TO_CHAR(TO_DATE(dc.month::TEXT, 'MM'), 'Month') AS month_name,
    ROUND(AVG(monthly.monthly_units), 0)            AS avg_monthly_units
FROM (
    SELECT
        DATE_TRUNC('month', date) AS month_start,
        EXTRACT(MONTH FROM date)  AS month,
        EXTRACT(YEAR FROM date)   AS year,
        SUM(units_sold)           AS monthly_units
    FROM fact_sales
    GROUP BY DATE_TRUNC('month', date), EXTRACT(MONTH FROM date), EXTRACT(YEAR FROM date)
) monthly
JOIN dim_calendar dc ON monthly.month = dc.month
GROUP BY dc.month
ORDER BY dc.month;


-- KPI 16: Holiday Impact Analysis
SELECT
    dc.event_name_1                     AS event_name,
    dc.event_type_1                     AS event_type,
    COUNT(DISTINCT dc.date)             AS event_days,
    ROUND(AVG(daily_sales.daily_units), 0) AS avg_daily_units_on_event,
    (
        SELECT ROUND(AVG(s2.units_sold), 0)
        FROM fact_sales s2
        JOIN dim_calendar dc2 ON s2.date = dc2.date
        WHERE dc2.is_event = FALSE
    )                                   AS avg_daily_units_normal,
    ROUND(
        (AVG(daily_sales.daily_units) - (
            SELECT AVG(s2.units_sold)
            FROM fact_sales s2
            JOIN dim_calendar dc2 ON s2.date = dc2.date
            WHERE dc2.is_event = FALSE
        )) / NULLIF((
            SELECT AVG(s2.units_sold)
            FROM fact_sales s2
            JOIN dim_calendar dc2 ON s2.date = dc2.date
            WHERE dc2.is_event = FALSE
        ), 0) * 100,
        2
    )                                   AS pct_lift_vs_normal
FROM (
    SELECT date, SUM(units_sold) AS daily_units
    FROM fact_sales
    GROUP BY date
) daily_sales
JOIN dim_calendar dc ON daily_sales.date = dc.date
WHERE dc.event_name_1 IS NOT NULL
GROUP BY dc.event_name_1, dc.event_type_1
ORDER BY pct_lift_vs_normal DESC;


-- KPI 17: SNAP Day Impact on FOODS Category
SELECT
    ds.state_id,
    is_snap_day,
    ROUND(AVG(daily_food_units), 2)     AS avg_daily_food_units
FROM (
    SELECT
        fs.date,
        ds.state_id,
        SUM(fs.units_sold)              AS daily_food_units,
        CASE ds.state_id
            WHEN 'CA' THEN dc.snap_CA
            WHEN 'TX' THEN dc.snap_TX
            WHEN 'WI' THEN dc.snap_WI
        END                             AS is_snap_day
    FROM fact_sales fs
    JOIN dim_product dp ON fs.product_id = dp.product_id
    JOIN dim_store ds ON fs.store_id = ds.store_id
    JOIN dim_calendar dc ON fs.date = dc.date
    WHERE dp.cat_id = 'FOODS'
    GROUP BY fs.date, ds.state_id, dc.snap_CA, dc.snap_TX, dc.snap_WI
) snap_data
GROUP BY ds.state_id, is_snap_day
ORDER BY ds.state_id, is_snap_day;


-- ============================================================
-- SECTION 6: PRICE ANALYSIS
-- ============================================================

-- KPI 18: Price Distribution by Category
SELECT
    dp.cat_id,
    ROUND(MIN(fp.sell_price)::NUMERIC, 2)  AS min_price,
    ROUND(AVG(fp.sell_price)::NUMERIC, 2)  AS avg_price,
    ROUND(MAX(fp.sell_price)::NUMERIC, 2)  AS max_price,
    ROUND(STDDEV(fp.sell_price)::NUMERIC, 2) AS price_std_dev,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY fp.sell_price) AS median_price
FROM fact_prices fp
JOIN dim_product dp ON fp.product_id = dp.product_id
GROUP BY dp.cat_id
ORDER BY avg_price DESC;


-- KPI 19: Price Changes Over Time (Price Volatility per Product)
WITH price_changes AS (
    SELECT
        fp.product_id,
        fp.store_id,
        fp.wm_yr_wk,
        fp.sell_price,
        LAG(fp.sell_price) OVER (
            PARTITION BY fp.product_id, fp.store_id
            ORDER BY fp.wm_yr_wk
        )                               AS prev_price
    FROM fact_prices fp
)
SELECT
    product_id,
    store_id,
    COUNT(*) FILTER (WHERE sell_price != prev_price AND prev_price IS NOT NULL) AS num_price_changes,
    ROUND(
        COUNT(*) FILTER (WHERE sell_price != prev_price AND prev_price IS NOT NULL)::NUMERIC /
        NULLIF(COUNT(*) - 1, 0) * 100,
        2
    )                                   AS pct_weeks_with_price_change
FROM price_changes
GROUP BY product_id, store_id
HAVING COUNT(*) FILTER (WHERE sell_price != prev_price AND prev_price IS NOT NULL) > 3
ORDER BY num_price_changes DESC
LIMIT 20;


-- KPI 20: Revenue Impact of Price vs Volume
SELECT
    dp.cat_id,
    ROUND(CORR(fp.sell_price, fs.units_sold)::NUMERIC, 4) AS price_demand_correlation
FROM fact_sales fs
JOIN dim_product dp ON fs.product_id = dp.product_id
JOIN fact_prices fp
    ON fs.store_id = fp.store_id
    AND fs.product_id = fp.product_id
    AND fp.wm_yr_wk = (SELECT wm_yr_wk FROM dim_calendar WHERE date = fs.date)
WHERE fs.units_sold > 0
GROUP BY dp.cat_id;


-- ============================================================
-- SECTION 7: INVENTORY & OPERATIONAL KPIs
-- ============================================================

-- KPI 21: Rolling 7-Day Average Demand (per SKU per Store)
SELECT
    fs.product_id,
    fs.store_id,
    fs.date,
    fs.units_sold,
    ROUND(AVG(fs.units_sold) OVER (
        PARTITION BY fs.product_id, fs.store_id
        ORDER BY fs.date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2)                               AS rolling_7d_avg_demand,
    ROUND(AVG(fs.units_sold) OVER (
        PARTITION BY fs.product_id, fs.store_id
        ORDER BY fs.date
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ), 2)                               AS rolling_30d_avg_demand
FROM fact_sales fs
WHERE fs.product_id IN (
    SELECT product_id FROM abc_classification WHERE abc_class = 'A' LIMIT 10
)
ORDER BY fs.product_id, fs.store_id, fs.date;


-- KPI 22: Products Below Reorder Point (Stockout Alert)
SELECT
    ir.product_id,
    ir.store_id,
    dp.cat_id,
    ir.reorder_point,
    ir.current_stock_proxy,
    ir.forecast_30d,
    CASE
        WHEN ir.current_stock_proxy <= 0                THEN 'CRITICAL — STOCKOUT'
        WHEN ir.current_stock_proxy < ir.reorder_point  THEN 'ORDER NOW'
        ELSE 'OK'
    END                                 AS alert_status
FROM inventory_recommendations ir
JOIN dim_product dp ON ir.product_id = dp.product_id
WHERE ir.current_stock_proxy < ir.reorder_point
ORDER BY ir.current_stock_proxy ASC;


-- KPI 23: ABC Classification Summary
SELECT
    abc_class,
    COUNT(*)                            AS num_skus,
    ROUND(
        COUNT(*)::NUMERIC /
        SUM(COUNT(*)) OVER () * 100,
        2
    )                                   AS pct_of_total_skus,
    ROUND(SUM(total_revenue)::NUMERIC, 2) AS total_revenue,
    ROUND(AVG(revenue_pct) * 100, 2)    AS avg_revenue_share_pct
FROM abc_classification
GROUP BY abc_class
ORDER BY abc_class;


-- KPI 24: Stockout Risk Summary by Store and Category
SELECT
    sr.store_id,
    dp.cat_id,
    COUNT(*) FILTER (WHERE sr.risk_level = 'HIGH')   AS high_risk_skus,
    COUNT(*) FILTER (WHERE sr.risk_level = 'MEDIUM') AS medium_risk_skus,
    COUNT(*) FILTER (WHERE sr.risk_level = 'LOW')    AS low_risk_skus,
    COUNT(*)                                          AS total_skus
FROM stockout_risk sr
JOIN dim_product dp ON sr.product_id = dp.product_id
GROUP BY sr.store_id, dp.cat_id
ORDER BY high_risk_skus DESC;


-- KPI 25: Demand Variability (Coefficient of Variation per SKU)
SELECT
    fs.product_id,
    fs.store_id,
    dp.cat_id,
    ROUND(AVG(fs.units_sold)::NUMERIC, 2)   AS avg_daily_demand,
    ROUND(STDDEV(fs.units_sold)::NUMERIC, 2) AS std_daily_demand,
    ROUND(
        STDDEV(fs.units_sold) / NULLIF(AVG(fs.units_sold), 0) * 100,
        2
    )                                        AS cv_pct,   -- Coefficient of Variation
    CASE
        WHEN STDDEV(fs.units_sold) / NULLIF(AVG(fs.units_sold), 0) > 1.0 THEN 'HIGH VARIABILITY'
        WHEN STDDEV(fs.units_sold) / NULLIF(AVG(fs.units_sold), 0) > 0.5 THEN 'MEDIUM VARIABILITY'
        ELSE 'LOW VARIABILITY'
    END                                      AS variability_class
FROM fact_sales fs
JOIN dim_product dp ON fs.product_id = dp.product_id
GROUP BY fs.product_id, fs.store_id, dp.cat_id
HAVING AVG(fs.units_sold) > 0
ORDER BY cv_pct DESC;


-- ============================================================
-- SECTION 8: ADVANCED ANALYTICS
-- ============================================================

-- KPI 26: Sales Growth Rate by Category (MoM)
WITH monthly_cat AS (
    SELECT
        dp.cat_id,
        DATE_TRUNC('month', fs.date) AS month,
        SUM(fs.units_sold)           AS monthly_units
    FROM fact_sales fs
    JOIN dim_product dp ON fs.product_id = dp.product_id
    GROUP BY dp.cat_id, DATE_TRUNC('month', fs.date)
)
SELECT
    cat_id,
    month,
    monthly_units,
    LAG(monthly_units) OVER (PARTITION BY cat_id ORDER BY month) AS prev_month_units,
    ROUND(
        (monthly_units - LAG(monthly_units) OVER (PARTITION BY cat_id ORDER BY month))::NUMERIC /
        NULLIF(LAG(monthly_units) OVER (PARTITION BY cat_id ORDER BY month), 0) * 100,
        2
    )                                   AS mom_growth_pct
FROM monthly_cat
ORDER BY cat_id, month;


-- KPI 27: Cumulative Revenue (Running Total)
SELECT
    date,
    daily_revenue,
    SUM(daily_revenue) OVER (ORDER BY date ROWS UNBOUNDED PRECEDING) AS cumulative_revenue
FROM (
    SELECT
        fs.date,
        ROUND(SUM(fs.units_sold * fp.sell_price)::NUMERIC, 2) AS daily_revenue
    FROM fact_sales fs
    JOIN fact_prices fp
        ON fs.store_id = fp.store_id
        AND fs.product_id = fp.product_id
        AND fp.wm_yr_wk = (SELECT wm_yr_wk FROM dim_calendar WHERE date = fs.date)
    WHERE fs.units_sold > 0
    GROUP BY fs.date
) daily
ORDER BY date;


-- KPI 28: Product Pairs Often Sold Together (Same Store, Same Day — Proxy)
-- (Market basket analysis proxy — top 10 category pairs)
SELECT
    a.cat_id  AS category_1,
    b.cat_id  AS category_2,
    COUNT(*)  AS co_occurrence_days
FROM (
    SELECT DISTINCT date, store_id, cat_id
    FROM vw_daily_sales
    WHERE units_sold > 0
) a
JOIN (
    SELECT DISTINCT date, store_id, cat_id
    FROM vw_daily_sales
    WHERE units_sold > 0
) b
    ON a.date = b.date AND a.store_id = b.store_id AND a.cat_id < b.cat_id
GROUP BY a.cat_id, b.cat_id
ORDER BY co_occurrence_days DESC;


-- KPI 29: Zero-Sales Days by Product (Stockout Proxy)
SELECT
    fs.product_id,
    fs.store_id,
    dp.cat_id,
    COUNT(*) FILTER (WHERE fs.units_sold = 0)   AS zero_sale_days,
    COUNT(*)                                     AS total_days,
    ROUND(
        COUNT(*) FILTER (WHERE fs.units_sold = 0)::NUMERIC / COUNT(*) * 100,
        2
    )                                            AS zero_sale_pct
FROM fact_sales fs
JOIN dim_product dp ON fs.product_id = dp.product_id
GROUP BY fs.product_id, fs.store_id, dp.cat_id
HAVING COUNT(*) FILTER (WHERE fs.units_sold = 0)::NUMERIC / COUNT(*) > 0.3
ORDER BY zero_sale_pct DESC
LIMIT 20;


-- KPI 30: Financial Impact Summary (Holding vs. Lost Sales Estimate)
SELECT
    dp.cat_id,
    SUM(ir.eoq * 0.25)                 AS estimated_annual_holding_cost_usd,
    ROUND(AVG(sr.days_to_stockout), 1) AS avg_days_to_stockout,
    COUNT(*) FILTER (WHERE sr.risk_level = 'HIGH') AS high_risk_sku_count
FROM inventory_recommendations ir
JOIN dim_product dp ON ir.product_id = dp.product_id
LEFT JOIN stockout_risk sr ON ir.product_id = sr.product_id AND ir.store_id = sr.store_id
GROUP BY dp.cat_id
ORDER BY estimated_annual_holding_cost_usd DESC;


-- ============================================================
-- BONUS QUERIES
-- ============================================================

-- BONUS 1: Top 5 Products Per Store (Window Function)
WITH ranked_products AS (
    SELECT
        fs.store_id,
        fs.product_id,
        dp.cat_id,
        SUM(fs.units_sold) AS total_units,
        RANK() OVER (PARTITION BY fs.store_id ORDER BY SUM(fs.units_sold) DESC) AS rank_in_store
    FROM fact_sales fs
    JOIN dim_product dp ON fs.product_id = dp.product_id
    GROUP BY fs.store_id, fs.product_id, dp.cat_id
)
SELECT * FROM ranked_products WHERE rank_in_store <= 5
ORDER BY store_id, rank_in_store;


-- BONUS 2: Demand Spike Detection (Z-Score)
WITH daily_stats AS (
    SELECT
        product_id,
        store_id,
        AVG(units_sold)   AS mean_demand,
        STDDEV(units_sold) AS std_demand
    FROM fact_sales
    GROUP BY product_id, store_id
)
SELECT
    fs.date,
    fs.product_id,
    fs.store_id,
    fs.units_sold,
    ROUND(ds.mean_demand::NUMERIC, 2)   AS mean_demand,
    ROUND(
        (fs.units_sold - ds.mean_demand) / NULLIF(ds.std_demand, 0),
        2
    )                                   AS z_score
FROM fact_sales fs
JOIN daily_stats ds USING (product_id, store_id)
WHERE ABS((fs.units_sold - ds.mean_demand) / NULLIF(ds.std_demand, 0)) > 3
ORDER BY ABS((fs.units_sold - ds.mean_demand) / NULLIF(ds.std_demand, 0)) DESC
LIMIT 50;


-- BONUS 3: Revenue Contribution by Store-Category Combination
SELECT
    store_id,
    cat_id,
    total_revenue,
    ROUND(
        total_revenue / SUM(total_revenue) OVER () * 100,
        2
    ) AS pct_of_total_revenue
FROM (
    SELECT
        fs.store_id,
        dp.cat_id,
        ROUND(SUM(fs.units_sold * fp.sell_price)::NUMERIC, 2) AS total_revenue
    FROM fact_sales fs
    JOIN dim_product dp ON fs.product_id = dp.product_id
    JOIN fact_prices fp
        ON fs.store_id = fp.store_id
        AND fs.product_id = fp.product_id
        AND fp.wm_yr_wk = (SELECT wm_yr_wk FROM dim_calendar WHERE date = fs.date)
    WHERE fs.units_sold > 0
    GROUP BY fs.store_id, dp.cat_id
) store_cat
ORDER BY pct_of_total_revenue DESC;

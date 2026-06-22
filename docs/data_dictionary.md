# Data Dictionary — Retail Demand Forecasting & Inventory Optimization

## Source Files (M5 Forecasting Dataset)

---

### `sales_train_validation.csv` (Wide Format — Raw)

| Column | Data Type | Description | Business Purpose |
|--------|-----------|-------------|------------------|
| `id` | string | Unique row identifier (item_store combination) | Primary key for joining |
| `item_id` | string | Product SKU identifier (e.g., `FOODS_3_090`) | Identifies the specific product |
| `dept_id` | string | Department (e.g., `FOODS_3`) | Groups products into departments |
| `cat_id` | string | Category: `FOODS`, `HOUSEHOLD`, `HOBBIES` | Top-level product grouping for analysis |
| `store_id` | string | Store identifier (e.g., `CA_1`) | Which store the sales occurred in |
| `state_id` | string | State: `CA`, `TX`, `WI` | Geographic region for analysis |
| `d_1`–`d_1913` | integer | Units sold on day N | Daily demand — the core metric to forecast |

> **Note:** This wide format must be melted to long format before analysis. Each day column becomes a row.

---

### `calendar.csv`

| Column | Data Type | Description | Business Purpose |
|--------|-----------|-------------|------------------|
| `date` | date | Calendar date (YYYY-MM-DD) | Primary join key to sales data |
| `wm_yr_wk` | integer | Walmart week number (year + week) | Joins to sell_prices.csv |
| `weekday` | string | Day name (Monday, Tuesday…) | Weekend effect analysis |
| `wday` | integer | Day of week (1=Saturday, 7=Friday) | Seasonality features |
| `month` | integer | Month (1–12) | Monthly trend analysis |
| `year` | integer | Year (2011–2016) | Year-over-year comparison |
| `d` | string | Day identifier (e.g., `d_1`) | Links calendar to sales columns |
| `event_name_1` | string | Name of primary event (e.g., `SuperBowl`) | Demand spike identification |
| `event_type_1` | string | Type: `Sporting`, `National`, `Religious`, `Cultural` | Event classification |
| `event_name_2` | string | Secondary event name (if two events on same day) | Multi-event analysis |
| `event_type_2` | string | Secondary event type | Event classification |
| `snap_CA` | integer | 1 if SNAP benefit day in California | SNAP drives +20-30% food demand |
| `snap_TX` | integer | 1 if SNAP benefit day in Texas | State-level demand modifier |
| `snap_WI` | integer | 1 if SNAP benefit day in Wisconsin | State-level demand modifier |

> **SNAP** = Supplemental Nutrition Assistance Program. Benefit payouts cause significant demand spikes in FOODS category.

---

### `sell_prices.csv`

| Column | Data Type | Description | Business Purpose |
|--------|-----------|-------------|------------------|
| `store_id` | string | Store identifier | Which store sells at this price |
| `item_id` | string | Product SKU | Which product |
| `wm_yr_wk` | integer | Walmart week number | Links to calendar.csv for exact date |
| `sell_price` | float | Retail sell price (USD) | Revenue calculation, price elasticity analysis |

---

## Database Tables (PostgreSQL — `retail_forecasting`)

---

### `dim_calendar` — Dimension Table

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `date` | DATE | NOT NULL (PK) | Calendar date |
| `wm_yr_wk` | INTEGER | NOT NULL | Walmart week key |
| `weekday` | VARCHAR(10) | NOT NULL | Day name |
| `wday` | INTEGER | NOT NULL | Day of week (1-7) |
| `month` | INTEGER | NOT NULL | Month (1-12) |
| `year` | INTEGER | NOT NULL | Year |
| `d` | VARCHAR(10) | NOT NULL | M5 day identifier |
| `event_name_1` | VARCHAR(100) | NULL | Primary event name |
| `event_type_1` | VARCHAR(50) | NULL | Primary event type |
| `event_name_2` | VARCHAR(100) | NULL | Secondary event name |
| `event_type_2` | VARCHAR(50) | NULL | Secondary event type |
| `snap_CA` | SMALLINT | NOT NULL | SNAP flag California |
| `snap_TX` | SMALLINT | NOT NULL | SNAP flag Texas |
| `snap_WI` | SMALLINT | NOT NULL | SNAP flag Wisconsin |
| `is_weekend` | BOOLEAN | NOT NULL | Derived: True if Sat or Sun |
| `is_event` | BOOLEAN | NOT NULL | Derived: True if any event |

---

### `dim_product` — Dimension Table

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `product_id` | VARCHAR(50) | NOT NULL (PK) | Unique product SKU |
| `item_id` | VARCHAR(50) | NOT NULL | M5 item identifier |
| `dept_id` | VARCHAR(50) | NOT NULL | Department code |
| `cat_id` | VARCHAR(20) | NOT NULL | Category: FOODS, HOUSEHOLD, HOBBIES |

---

### `dim_store` — Dimension Table

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `store_id` | VARCHAR(20) | NOT NULL (PK) | Store identifier |
| `state_id` | VARCHAR(10) | NOT NULL | State: CA, TX, WI |

---

### `fact_sales` — Fact Table (Core)

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `id` | BIGSERIAL | NOT NULL (PK) | Surrogate key |
| `date` | DATE | NOT NULL (FK → dim_calendar) | Sale date |
| `product_id` | VARCHAR(50) | NOT NULL (FK → dim_product) | Product sold |
| `store_id` | VARCHAR(20) | NOT NULL (FK → dim_store) | Store where sold |
| `units_sold` | INTEGER | NOT NULL | Quantity sold (0 = no sale, not missing) |

---

### `fact_prices` — Fact Table

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `id` | BIGSERIAL | NOT NULL (PK) | Surrogate key |
| `store_id` | VARCHAR(20) | NOT NULL (FK → dim_store) | Store |
| `product_id` | VARCHAR(50) | NOT NULL (FK → dim_product) | Product |
| `wm_yr_wk` | INTEGER | NOT NULL | Week number |
| `sell_price` | NUMERIC(10,2) | NOT NULL | Price (USD) |

---

## Derived / Analytical Tables (Created in Notebooks)

### `abc_classification`

| Column | Description |
|--------|-------------|
| `product_id` | SKU |
| `store_id` | Store |
| `total_revenue` | Total revenue for analysis period |
| `revenue_pct` | Percentage of total revenue |
| `cumulative_pct` | Cumulative revenue percentage |
| `abc_class` | A = top 70%, B = next 20%, C = bottom 10% |

### `inventory_recommendations`

| Column | Description |
|--------|-------------|
| `product_id` | SKU |
| `store_id` | Store |
| `avg_daily_demand` | Average daily units sold |
| `demand_std` | Standard deviation of daily demand |
| `lead_time_days` | Assumed supplier lead time |
| `safety_stock` | Safety stock units |
| `reorder_point` | Trigger reorder at this stock level |
| `eoq` | Economic Order Quantity (optimal order size) |
| `forecast_30d` | Prophet 30-day demand forecast |
| `recommended_order` | Recommended order quantity |

### `stockout_risk`

| Column | Description |
|--------|-------------|
| `product_id` | SKU |
| `store_id` | Store |
| `current_stock_proxy` | Rolling 14-day stock proxy |
| `forecast_demand_7d` | 7-day demand forecast |
| `risk_score` | Numeric risk score |
| `risk_level` | LOW / MEDIUM / HIGH |
| `days_to_stockout` | Estimated days until stockout |

---

## Business Metrics Glossary

| Term | Formula | Description |
|------|---------|-------------|
| **EOQ** | √(2DS/H) | Economic Order Quantity. D=demand, S=order cost, H=holding cost |
| **Safety Stock** | Z × σ × √L | Buffer stock. Z=service level, σ=demand std dev, L=lead time |
| **Reorder Point** | (Avg demand × Lead time) + Safety Stock | Order when inventory hits this level |
| **MAPE** | mean(|actual-forecast|/actual) × 100 | Mean Absolute Percentage Error |
| **MAE** | mean(|actual-forecast|) | Mean Absolute Error in units |
| **RMSE** | √mean((actual-forecast)²) | Root Mean Squared Error |
| **ABC Class A** | Cumulative revenue ≤ 70% | High-priority SKUs |
| **ABC Class B** | 70% < Cumulative ≤ 90% | Medium-priority SKUs |
| **ABC Class C** | Cumulative > 90% | Low-priority SKUs |
| **Inventory Turnover** | COGS / Avg Inventory | How many times inventory sold in a period |
| **Holding Cost** | Units × Days × Holding rate | Cost of storing unsold inventory |

-- ============================================================
-- Retail Demand Forecasting & Inventory Optimization
-- PostgreSQL Schema — retail_forecasting database
-- ============================================================

-- Run as: psql -U postgres -d retail_forecasting -f sql/schema.sql

-- ============================================================
-- DROP EXISTING TABLES (clean slate if re-running)
-- ============================================================
DROP TABLE IF EXISTS stockout_risk CASCADE;
DROP TABLE IF EXISTS inventory_recommendations CASCADE;
DROP TABLE IF EXISTS abc_classification CASCADE;
DROP TABLE IF EXISTS fact_prices CASCADE;
DROP TABLE IF EXISTS fact_sales CASCADE;
DROP TABLE IF EXISTS dim_store CASCADE;
DROP TABLE IF EXISTS dim_product CASCADE;
DROP TABLE IF EXISTS dim_calendar CASCADE;

-- ============================================================
-- DIMENSION TABLES
-- ============================================================

-- dim_calendar: Date dimension enriched with event & SNAP flags
CREATE TABLE dim_calendar (
    date            DATE            NOT NULL,
    wm_yr_wk        INTEGER         NOT NULL,
    weekday         VARCHAR(10)     NOT NULL,
    wday            SMALLINT        NOT NULL,  -- 1=Saturday, 7=Friday
    month           SMALLINT        NOT NULL,
    year            SMALLINT        NOT NULL,
    d               VARCHAR(10)     NOT NULL,  -- e.g. 'd_1', 'd_1913'
    event_name_1    VARCHAR(100),
    event_type_1    VARCHAR(50),
    event_name_2    VARCHAR(100),
    event_type_2    VARCHAR(50),
    snap_CA         SMALLINT        NOT NULL DEFAULT 0,
    snap_TX         SMALLINT        NOT NULL DEFAULT 0,
    snap_WI         SMALLINT        NOT NULL DEFAULT 0,
    is_weekend      BOOLEAN         NOT NULL GENERATED ALWAYS AS (wday IN (1, 2)) STORED,
    is_event        BOOLEAN         NOT NULL GENERATED ALWAYS AS (event_name_1 IS NOT NULL) STORED,
    CONSTRAINT pk_calendar PRIMARY KEY (date)
);

CREATE INDEX idx_calendar_year_month ON dim_calendar (year, month);
CREATE INDEX idx_calendar_wm_yr_wk   ON dim_calendar (wm_yr_wk);
CREATE INDEX idx_calendar_d          ON dim_calendar (d);

COMMENT ON TABLE dim_calendar IS 'Date dimension with M5 event and SNAP flags';
COMMENT ON COLUMN dim_calendar.wday IS '1=Saturday, 2=Sunday, 3=Monday ... 7=Friday';
COMMENT ON COLUMN dim_calendar.snap_CA IS 'SNAP benefit disbursement day in California (1=yes)';


-- dim_product: Product/SKU dimension
CREATE TABLE dim_product (
    product_id      VARCHAR(50)     NOT NULL,
    item_id         VARCHAR(50)     NOT NULL,
    dept_id         VARCHAR(50)     NOT NULL,
    cat_id          VARCHAR(20)     NOT NULL,
    CONSTRAINT pk_product PRIMARY KEY (product_id)
);

CREATE INDEX idx_product_cat   ON dim_product (cat_id);
CREATE INDEX idx_product_dept  ON dim_product (dept_id);

COMMENT ON TABLE dim_product IS 'Product dimension. cat_id: FOODS | HOUSEHOLD | HOBBIES';


-- dim_store: Store dimension
CREATE TABLE dim_store (
    store_id        VARCHAR(20)     NOT NULL,
    state_id        VARCHAR(10)     NOT NULL,
    CONSTRAINT pk_store PRIMARY KEY (store_id)
);

COMMENT ON TABLE dim_store IS 'Store dimension. state_id: CA | TX | WI';


-- ============================================================
-- FACT TABLES
-- ============================================================

-- fact_sales: Core daily sales fact (long format)
CREATE TABLE fact_sales (
    id              BIGSERIAL       NOT NULL,
    date            DATE            NOT NULL,
    product_id      VARCHAR(50)     NOT NULL,
    store_id        VARCHAR(20)     NOT NULL,
    units_sold      INTEGER         NOT NULL DEFAULT 0,
    CONSTRAINT pk_sales PRIMARY KEY (id),
    CONSTRAINT fk_sales_date    FOREIGN KEY (date)       REFERENCES dim_calendar(date),
    CONSTRAINT fk_sales_product FOREIGN KEY (product_id) REFERENCES dim_product(product_id),
    CONSTRAINT fk_sales_store   FOREIGN KEY (store_id)   REFERENCES dim_store(store_id),
    CONSTRAINT chk_units_sold   CHECK (units_sold >= 0)
);

CREATE INDEX idx_sales_date       ON fact_sales (date);
CREATE INDEX idx_sales_product    ON fact_sales (product_id);
CREATE INDEX idx_sales_store      ON fact_sales (store_id);
CREATE INDEX idx_sales_date_prod  ON fact_sales (date, product_id, store_id);

COMMENT ON TABLE fact_sales IS 'Daily sales fact. 0 = no sale that day (not missing).';


-- fact_prices: Weekly sell price per product per store
CREATE TABLE fact_prices (
    id              BIGSERIAL       NOT NULL,
    store_id        VARCHAR(20)     NOT NULL,
    product_id      VARCHAR(50)     NOT NULL,
    wm_yr_wk        INTEGER         NOT NULL,
    sell_price      NUMERIC(10,2)   NOT NULL,
    CONSTRAINT pk_prices PRIMARY KEY (id),
    CONSTRAINT fk_prices_store   FOREIGN KEY (store_id)   REFERENCES dim_store(store_id),
    CONSTRAINT fk_prices_product FOREIGN KEY (product_id) REFERENCES dim_product(product_id),
    CONSTRAINT chk_price         CHECK (sell_price > 0)
);

CREATE INDEX idx_prices_store_prod ON fact_prices (store_id, product_id);
CREATE INDEX idx_prices_wm_yr_wk   ON fact_prices (wm_yr_wk);

COMMENT ON TABLE fact_prices IS 'Weekly sell price by store and product.';


-- ============================================================
-- ANALYTICAL TABLES (Populated by Python notebooks)
-- ============================================================

-- abc_classification: ABC inventory analysis output
CREATE TABLE abc_classification (
    product_id          VARCHAR(50)     NOT NULL,
    store_id            VARCHAR(20)     NOT NULL,
    total_units_sold    BIGINT          NOT NULL,
    total_revenue       NUMERIC(15,2)   NOT NULL,
    revenue_pct         NUMERIC(6,4)    NOT NULL,
    cumulative_pct      NUMERIC(6,4)    NOT NULL,
    abc_class           CHAR(1)         NOT NULL,
    analysis_date       DATE            NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT pk_abc PRIMARY KEY (product_id, store_id),
    CONSTRAINT chk_abc_class CHECK (abc_class IN ('A', 'B', 'C'))
);

COMMENT ON TABLE abc_classification IS 'A=top 70% revenue, B=next 20%, C=bottom 10%';


-- inventory_recommendations: Optimization engine output
CREATE TABLE inventory_recommendations (
    product_id              VARCHAR(50)     NOT NULL,
    store_id                VARCHAR(20)     NOT NULL,
    avg_daily_demand        NUMERIC(10,4),
    demand_std              NUMERIC(10,4),
    lead_time_days          INTEGER,
    service_level_z         NUMERIC(5,2),
    safety_stock            INTEGER,
    reorder_point           INTEGER,
    eoq                     INTEGER,
    forecast_30d            NUMERIC(10,2),
    current_stock_proxy     INTEGER,
    recommended_order_qty   INTEGER,
    analysis_date           DATE NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT pk_inv_rec PRIMARY KEY (product_id, store_id)
);

COMMENT ON TABLE inventory_recommendations IS 'EOQ, safety stock, and reorder point per SKU per store.';


-- stockout_risk: Risk detection output
CREATE TABLE stockout_risk (
    product_id          VARCHAR(50)     NOT NULL,
    store_id            VARCHAR(20)     NOT NULL,
    current_stock_proxy INTEGER,
    forecast_demand_7d  NUMERIC(10,2),
    risk_score          NUMERIC(6,4),
    risk_level          VARCHAR(10),
    days_to_stockout    INTEGER,
    alert_date          DATE NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT pk_stockout PRIMARY KEY (product_id, store_id),
    CONSTRAINT chk_risk_level CHECK (risk_level IN ('LOW', 'MEDIUM', 'HIGH'))
);

COMMENT ON TABLE stockout_risk IS 'Stockout risk flags: LOW | MEDIUM | HIGH per SKU per store.';


-- ============================================================
-- USEFUL VIEWS
-- ============================================================

-- vw_daily_sales: Sales enriched with all dimensions
CREATE OR REPLACE VIEW vw_daily_sales AS
SELECT
    fs.id,
    fs.date,
    dc.year,
    dc.month,
    dc.weekday,
    dc.is_weekend,
    dc.is_event,
    dc.event_name_1,
    dc.snap_CA,
    dc.snap_TX,
    dc.snap_WI,
    fs.product_id,
    dp.dept_id,
    dp.cat_id,
    fs.store_id,
    ds.state_id,
    fs.units_sold
FROM fact_sales fs
JOIN dim_calendar dc ON fs.date = dc.date
JOIN dim_product  dp ON fs.product_id = dp.product_id
JOIN dim_store    ds ON fs.store_id = ds.store_id;

COMMENT ON VIEW vw_daily_sales IS 'Denormalized daily sales with all dimension attributes joined.';


-- vw_daily_sales_with_revenue: Sales + pricing
CREATE OR REPLACE VIEW vw_daily_sales_with_revenue AS
SELECT
    vds.*,
    fp.sell_price,
    (vds.units_sold * fp.sell_price) AS revenue
FROM vw_daily_sales vds
LEFT JOIN fact_prices fp
    ON vds.store_id = fp.store_id
    AND vds.product_id = fp.product_id
    AND fp.wm_yr_wk = (
        SELECT wm_yr_wk FROM dim_calendar WHERE date = vds.date
    );

COMMENT ON VIEW vw_daily_sales_with_revenue IS 'Daily sales with revenue (units × price).';


-- ============================================================
-- SCHEMA SUMMARY
-- ============================================================
-- Tables:
--   dim_calendar            → Date features, events, SNAP flags
--   dim_product             → SKU, department, category
--   dim_store               → Store, state
--   fact_sales              → Daily units sold (long format)
--   fact_prices             → Weekly price per store/SKU
--   abc_classification      → ABC analysis results
--   inventory_recommendations → EOQ, safety stock, ROP
--   stockout_risk           → Risk detection output
-- Views:
--   vw_daily_sales          → Denormalized sales
--   vw_daily_sales_with_revenue → Sales with revenue
-- ============================================================

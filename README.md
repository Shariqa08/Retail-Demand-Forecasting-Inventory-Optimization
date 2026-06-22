# Retail Demand Forecasting & Inventory Optimization
### End-to-End Data Analyst Portfolio Project

![Python](https://img.shields.io/badge/Python-3.10%2B-blue?logo=python)
![Pandas](https://img.shields.io/badge/Pandas-Data_Processing-150458?logo=pandas)
![Prophet](https://img.shields.io/badge/Prophet-Forecasting-orange)
![Scikit-Learn](https://img.shields.io/badge/Scikit--Learn-Machine_Learning-F7931E?logo=scikit-learn)
![Parquet](https://img.shields.io/badge/Apache_Parquet-Storage-green)

---

## Business Problem

Retail companies constantly struggle with two costly extremes:

| Problem | Cause | Business Impact |
|---|---|---|
| **Stockout** | Demand > Inventory | Lost sales, lost customers, reduced revenue |
| **Overstock** | Inventory > Demand | Holding costs, warehouse costs, cash locked up |

**The Goal:** Predict future product demand with high accuracy and use those predictions to optimize inventory levels, balancing the cost of holding inventory against the risk of losing sales.

---

## Project Overview

This project is a complete, end-to-end analytics solution demonstrating how a data analyst solves real-world supply chain problems. Using the **M5 Forecasting dataset**, I constructed a highly optimized, file-based analytical pipeline using Python and Parquet.

### Key Deliverables:
1. **Automated ETL Pipeline**: Melted and aggregated wide-format sales data into a high-performance Parquet schema.
2. **Exploratory Data Analysis (EDA)**: Analyzed seasonality, holiday impacts, and category trends.
3. **Demand Forecasting**: Trained Facebook Prophet models to forecast 30-day and 90-day demand horizons across categories and stores.
4. **Inventory Optimization Engine**: Calculated Economic Order Quantity (EOQ), Safety Stock, and Reorder Points using historical volatility and forecast data.
5. **Stockout Risk Detection**: Flagged SKUs with high stockout probabilities based on expected demand vs. current stock levels.
6. **ABC Analysis**: Classified inventory into A, B, and C tiers based on Pareto revenue contribution.

---

## Analytical Architecture

To ensure fast execution and portability, this project relies on a **Pure Parquet Architecture** instead of a traditional relational database.

1. **Raw Data**: M5 CSV files (Sales, Calendar, Prices).
2. **ETL Processing**: Python (Pandas) converts wide formats to long formats and joins dimensional data.
3. **Storage**: Compressed `.parquet` files for blazing-fast read/write speeds.
4. **Analytics Layer**: Jupyter Notebooks pull directly from Parquet to train models and run inventory simulations.

---

## Notebooks & Workflow

The core analysis is broken down into a structured sequence of Jupyter Notebooks:

### `01_data_audit.ipynb`
* **Objective:** Initial inspection of the raw M5 datasets.
* **Findings:** Identified data sparsity, missing prices, and the need to melt 1,913 day-columns into a relational format.

### `02_data_cleaning.ipynb`
* **Objective:** Data engineering and ETL.
* **Action:** Converted wide-format sales to long-format, joined calendar events (holidays, SNAP days), and merged pricing data. 
* **Output:** Saved highly compressed `daily_aggregated.parquet` and `sales_enriched_sample.parquet` files.

### `03_eda.ipynb`
* **Objective:** Exploratory Data Analysis.
* **Insights:** 
  - Mapped out strong weekly seasonality (peaks on weekends).
  - Quantified the exact percentage lift on sales during SNAP benefit days.
  - Analyzed category-level revenue distributions.

### `04_forecasting.ipynb`
* **Objective:** Time-series forecasting.
* **Action:** Trained **Facebook Prophet** models incorporating US holidays and weekly/yearly seasonality. Evaluated models using MAE, RMSE, and MAPE.
* **Output:** Generated 90-day category forecasts and 30-day store-level forecasts.

### `05_inventory.ipynb`
* **Objective:** Supply chain optimization and risk management.
* **Action:**
  - **ABC Classification:** Applied the 70/20/10 rule to identify the most critical revenue-driving SKUs.
  - **Inventory Metrics:** Calculated Safety Stock (95% service level) and EOQ to minimize holding and ordering costs.
  - **Risk Engine:** Flagged "HIGH RISK" SKUs where 7-day predicted demand exceeds current proxy stock.
  - **Financial Impact:** Estimated the monthly financial impact of overstocking and understocking.

---

## Key Business Insights

1. **Class A Dominance:** A small fraction of SKUs drives the vast majority of revenue. These require strict monitoring and higher safety stock buffers to prevent out-of-stock events.
2. **Event-Driven Demand:** Forecasting accuracy significantly improves when incorporating SNAP benefit days and major holidays, especially for the FOODS category.
3. **Reorder Automation:** By implementing Reorder Points (ROP) derived from lead times and safety stock, the business can shift from reactive ordering to proactive inventory management, mitigating the identified "HIGH RISK" stockouts.

---

## How to Run

1. **Install Dependencies:**
   ```bash
   pip install -r requirements.txt
   ```
2. **Provide Raw Data:**
   Ensure the M5 dataset CSV files (`sales_train_validation.csv`, `calendar.csv`, `sell_prices.csv`) are located in the `Data/` directory.
3. **Run the ETL Pipeline:**
   Execute the ETL script to generate the Parquet database.
   ```bash
   python sql/load_data.py
   ```
4. **Explore the Analysis:**
   Open the Jupyter Notebooks in sequence (03 -> 04 -> 05) to view the analysis, forecasting, and optimization steps.

---
*Created as a comprehensive demonstration of data engineering, predictive modeling, and business intelligence in Python.*

"""
Retail Demand Forecasting & Inventory Optimization
ETL Script — Pure Parquet (No Database Required)
==================================================
Run from project root:
    python sql/load_data.py

Reads from:  Data/ (M5 CSV files)
Writes to:   Data/processed/ (parquet files)

Produces the same outputs as Notebook 02 but as a standalone CLI script.
"""

import pandas as pd
import numpy as np
from pathlib import Path
from tqdm import tqdm
import time, logging, sys

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s  %(levelname)s  %(message)s',
    datefmt='%H:%M:%S'
)
log = logging.getLogger('etl')

# ── Paths ──────────────────────────────────────────────────────────────────────
DATA_RAW  = Path("Data")
DATA_PROC = Path("Data/processed")
DATA_PROC.mkdir(parents=True, exist_ok=True)

REQUIRED_FILES = [
    "sales_train_validation.csv",
    "calendar.csv",
    "sell_prices.csv",
]

# ── Validate ───────────────────────────────────────────────────────────────────
def validate_inputs():
    missing = [f for f in REQUIRED_FILES if not (DATA_RAW / f).exists()]
    if missing:
        for f in missing:
            log.error(f"Missing file: Data/{f}")
        sys.exit(1)
    log.info("All input files found")


# ── Load ───────────────────────────────────────────────────────────────────────
def load_raw():
    log.info("Loading raw CSV files ...")
    sales    = pd.read_csv(DATA_RAW / "sales_train_validation.csv")
    calendar = pd.read_csv(DATA_RAW / "calendar.csv", parse_dates=["date"])
    prices   = pd.read_csv(DATA_RAW / "sell_prices.csv")

    log.info(f"  sales    : {sales.shape[0]:,} rows × {sales.shape[1]} cols")
    log.info(f"  calendar : {calendar.shape[0]:,} rows")
    log.info(f"  prices   : {prices.shape[0]:,} rows")
    return sales, calendar, prices


# ── Calendar ───────────────────────────────────────────────────────────────────
def save_calendar(calendar):
    cal = calendar[[
        "date", "d", "wm_yr_wk", "weekday", "wday", "month", "year",
        "event_name_1", "event_type_1", "event_name_2", "event_type_2",
        "snap_CA", "snap_TX", "snap_WI"
    ]].copy()
    cal.to_parquet(DATA_PROC / "calendar_clean.parquet", index=False)
    log.info(f"Saved calendar_clean.parquet: {len(cal):,} rows")
    return cal


# ── Melt + Aggregate ───────────────────────────────────────────────────────────
def melt_and_aggregate(sales, cal, prices):
    id_cols  = ["id", "item_id", "dept_id", "cat_id", "store_id", "state_id"]
    day_cols = [c for c in sales.columns if c.startswith("d_")]

    # Top 200 SKUs by total sales
    total_sales = sales[day_cols].sum(axis=1)
    top_200_ids = set(sales.loc[total_sales.nlargest(200).index, "id"])
    log.info(f"Top 200 SKUs identified (min lifetime sales: {total_sales.nlargest(200).min():,})")

    BATCH = 300
    agg_chunks    = []
    sample_chunks = []
    start = time.time()

    for i in tqdm(range(0, len(sales), BATCH), desc="Melting wide→long"):
        chunk = sales.iloc[i: i + BATCH]

        melted = chunk.melt(
            id_vars=id_cols,
            value_vars=day_cols,
            var_name="d",
            value_name="units_sold"
        )
        melted["units_sold"] = melted["units_sold"].fillna(0).astype(np.int32)

        # Join calendar
        cal_cols = ["d", "date", "wm_yr_wk", "year", "month", "weekday", "wday",
                    "event_name_1", "event_type_1", "snap_CA", "snap_TX", "snap_WI"]
        melted = melted.merge(cal[cal_cols], on="d", how="left")

        # Join prices
        melted = melted.merge(
            prices[["store_id", "item_id", "wm_yr_wk", "sell_price"]],
            on=["store_id", "item_id", "wm_yr_wk"],
            how="left"
        )
        melted["revenue"] = melted["units_sold"] * melted["sell_price"].fillna(0)

        # Daily aggregation
        agg = melted.groupby(
            ["date", "cat_id", "dept_id", "store_id", "state_id",
             "year", "month", "weekday", "wday", "event_name_1",
             "snap_CA", "snap_TX", "snap_WI"],
            dropna=False
        ).agg(total_units=("units_sold", "sum"),
              total_revenue=("revenue", "sum")).reset_index()
        agg_chunks.append(agg)

        # Sample (top 200 only)
        mask = melted["id"].isin(top_200_ids)
        if mask.any():
            sample = melted.loc[mask, [
                "date", "id", "item_id", "dept_id", "cat_id",
                "store_id", "state_id", "year", "month", "weekday", "wday",
                "event_name_1", "snap_CA", "snap_TX", "snap_WI",
                "units_sold", "sell_price"
            ]].rename(columns={"id": "product_id"})
            sample_chunks.append(sample)

    elapsed = time.time() - start
    log.info(f"Melt complete in {elapsed/60:.1f} minutes")
    return agg_chunks, sample_chunks


# ── Save ───────────────────────────────────────────────────────────────────────
def save_outputs(agg_chunks, sample_chunks):
    log.info("Consolidating and saving daily_aggregated.parquet ...")
    daily_agg = pd.concat(agg_chunks, ignore_index=True)
    daily_agg = daily_agg.groupby(
        ["date", "cat_id", "dept_id", "store_id", "state_id",
         "year", "month", "weekday", "wday", "event_name_1",
         "snap_CA", "snap_TX", "snap_WI"],
        dropna=False
    ).agg(total_units=("total_units", "sum"),
          total_revenue=("total_revenue", "sum")).reset_index()

    daily_agg.to_parquet(DATA_PROC / "daily_aggregated.parquet", index=False)
    log.info(f"  Saved daily_aggregated.parquet: {len(daily_agg):,} rows")

    log.info("Consolidating and saving sales_enriched_sample.parquet ...")
    df_sample = pd.concat(sample_chunks, ignore_index=True)
    df_sample.to_parquet(DATA_PROC / "sales_enriched_sample.parquet", index=False)
    log.info(f"  Saved sales_enriched_sample.parquet: {len(df_sample):,} rows ({df_sample['product_id'].nunique()} SKUs)")


# ── Verify ──────────────────────────────────────────────────────────────────────
def verify_outputs():
    log.info("\n=== Output Verification ===")
    for fname in ["calendar_clean.parquet", "daily_aggregated.parquet", "sales_enriched_sample.parquet"]:
        path = DATA_PROC / fname
        if path.exists():
            df  = pd.read_parquet(path)
            mb  = path.stat().st_size / 1e6
            log.info(f"  OK  {fname}  ({len(df):,} rows, {mb:.1f} MB)")
        else:
            log.error(f"  MISSING  {fname}")


# ── Main ───────────────────────────────────────────────────────────────────────
def main():
    log.info("=" * 55)
    log.info("  Retail Demand Forecasting — ETL (Parquet)")
    log.info("=" * 55)

    validate_inputs()
    sales, calendar, prices = load_raw()
    cal = save_calendar(calendar)
    agg_chunks, sample_chunks = melt_and_aggregate(sales, cal, prices)
    save_outputs(agg_chunks, sample_chunks)
    verify_outputs()

    log.info("\nETL complete. Run notebooks 03-05 or the Streamlit dashboard.")


if __name__ == "__main__":
    main()

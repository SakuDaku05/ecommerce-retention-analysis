"""Step 1: load the CSV into Postgres, run the SQL files, save result CSVs and charts.

Run:  python run_analysis.py
Needs a Postgres reachable with the settings below (see ../docker-compose.yml).
"""
import io
import os
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import psycopg2

HERE = Path(__file__).parent
SQL = HERE / "sql"
OUT = HERE / "outputs"
OUT.mkdir(exist_ok=True)

DB = dict(
    host=os.getenv("PGHOST", "localhost"),
    port=int(os.getenv("PGPORT", "5433")),
    user=os.getenv("PGUSER", "postgres"),
    password=os.getenv("PGPASSWORD", "postgres"),
)
DBNAME = "retention_analysis"


def ensure_database() -> None:
    conn = psycopg2.connect(dbname="postgres", **DB)
    conn.autocommit = True
    cur = conn.cursor()
    cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (DBNAME,))
    if not cur.fetchone():
        cur.execute(f"CREATE DATABASE {DBNAME}")
    conn.close()


def load_raw(conn) -> None:
    """Load data/online_retail.csv into raw_online_retail using pandas + COPY."""
    df = pd.read_csv(HERE / "data" / "online_retail.csv")
    df.columns = ["invoice_no", "stock_code", "description", "quantity",
                  "invoice_date", "unit_price", "customer_id", "country"]
    cur = conn.cursor()
    cur.execute("DROP TABLE IF EXISTS raw_online_retail CASCADE")
    cur.execute("""
        CREATE TABLE raw_online_retail (
            invoice_no text, stock_code text, description text, quantity int,
            invoice_date timestamp, unit_price numeric(10,2), customer_id numeric, country text)""")
    buf = io.StringIO()
    df.to_csv(buf, index=False, header=False)
    buf.seek(0)
    cur.copy_expert("COPY raw_online_retail FROM STDIN WITH (FORMAT csv)", buf)
    conn.commit()
    print(f"Loaded {len(df):,} raw rows")


def run_query(conn, name: str) -> pd.DataFrame:
    df = pd.read_sql_query((SQL / name).read_text(), conn)
    df.to_csv(OUT / name.replace(".sql", ".csv"), index=False)
    return df


def chart_funnel(df: pd.DataFrame) -> None:
    fig, ax = plt.subplots(figsize=(8, 4))
    ax.barh(df["stage_name"][::-1], df["customers_reached"][::-1], color="#1F3864")
    for y, (n, p) in enumerate(zip(df["customers_reached"][::-1], df["pct_of_acquired"][::-1])):
        ax.text(n, y, f"  {n:,} ({p}%)", va="center", fontsize=9)
    ax.set_title("Customer journey funnel: acquisition to repeat purchase")
    ax.set_xlim(0, df["customers_reached"].max() * 1.25)
    ax.spines[["top", "right"]].set_visible(False)
    fig.tight_layout()
    fig.savefig(OUT / "funnel.png", dpi=150)
    plt.close(fig)


def chart_cohorts(df: pd.DataFrame) -> None:
    pivot = df.pivot(index="cohort_month", columns="month_index", values="retention_pct")
    fig, ax = plt.subplots(figsize=(9, 5))
    im = ax.imshow(pivot.values, cmap="Blues", vmin=0, vmax=60, aspect="auto")
    ax.set_xticks(range(pivot.shape[1]), pivot.columns)
    ax.set_yticks(range(pivot.shape[0]), [str(d)[:7] for d in pivot.index])
    for i in range(pivot.shape[0]):
        for j in range(pivot.shape[1]):
            v = pivot.values[i, j]
            if not np.isnan(v):
                ax.text(j, i, f"{v:.0f}", ha="center", va="center", fontsize=7,
                        color="white" if v > 35 else "black")
    ax.set_xlabel("Months since first purchase")
    ax.set_ylabel("Cohort (first purchase month)")
    ax.set_title("Monthly cohort retention (%)")
    fig.colorbar(im, ax=ax, label="% of cohort active")
    fig.tight_layout()
    fig.savefig(OUT / "cohort_retention.png", dpi=150)
    plt.close(fig)


def chart_segments(df: pd.DataFrame) -> None:
    fig, axes = plt.subplots(1, 2, figsize=(10, 4), sharey=True)
    for ax, (seg_type, g) in zip(axes, df.groupby("segment_type")):
        ax.bar(g["segment"], g["return_90d_pct"], color="#1F3864")
        for x, v in enumerate(g["return_90d_pct"]):
            ax.text(x, v, f"{v}%", ha="center", va="bottom", fontsize=9)
        ax.set_title(seg_type)
        ax.tick_params(axis="x", rotation=20)
        ax.spines[["top", "right"]].set_visible(False)
    axes[0].set_ylabel("90-day return rate (%)")
    fig.tight_layout()
    fig.savefig(OUT / "segment_comparison.png", dpi=150)
    plt.close(fig)


def main() -> None:
    ensure_database()
    conn = psycopg2.connect(dbname=DBNAME, **DB)
    load_raw(conn)
    cur = conn.cursor()
    cur.execute((SQL / "01_prepare.sql").read_text())
    conn.commit()
    cur.execute("SELECT COUNT(*), COUNT(DISTINCT customer_id) FROM clean_transactions")
    print("clean line items / customers:", cur.fetchone())
    cur.execute("SELECT COUNT(*) FROM purchases")
    print("purchase days:", cur.fetchone()[0])

    funnel = run_query(conn, "02_journey_funnel.sql")
    cohorts = run_query(conn, "03_cohort_retention.sql")
    returns = run_query(conn, "04_return_rates_30_60_90.sql")
    segments = run_query(conn, "05_segment_comparison.sql")
    timing = run_query(conn, "06_repeat_timing.sql")
    conn.close()

    chart_funnel(funnel)
    chart_cohorts(cohorts)
    chart_segments(segments)

    pd.set_option("display.width", 200)
    print("\n== Journey funnel ==\n", funnel.to_string(index=False))
    print("\n== Return rates by cohort ==\n", returns.to_string(index=False))
    print("\n== Segments (90-day return) ==\n", segments.to_string(index=False))
    print("\n== Repeat timing (LAG / LEAD) ==\n", timing.to_string(index=False))
    print("\nCharts and CSVs saved in", OUT)


if __name__ == "__main__":
    main()

# ecommerce-retention-analysis: Funnel & Cohort Study

A small SQL project that follows e-commerce customers from their **first purchase to repeat purchases**, finds where the journey loses the most people, and measures **30/60/90-day return rates** by monthly cohort.

**Stack:** SQL (Postgres), Python (pandas, matplotlib)

## Data
UCI **Online Retail** dataset (public, CC BY 4.0): 541,909 line items from a UK online gift retailer, 1 Dec 2010 to 9 Dec 2011.
`00_download_data.py` downloads it for you. After cleaning (below): **392,688 line items, 4,338 customers, 16,763 purchase days.**

## Run it
```bash
docker compose -f ../docker-compose.yml up -d     # Postgres on localhost:5433
pip install pandas psycopg2-binary matplotlib openpyxl
python 00_download_data.py                         # -> data/online_retail.csv
python run_analysis.py                             # loads, runs the SQL, writes outputs/
```

## What each file teaches
| File | Question it answers | SQL skills |
|---|---|---|
| `sql/01_prepare.sql` | Which rows can we trust? | cleaning, `DISTINCT`, `GROUP BY`, `ROW_NUMBER`, `LAG`, `LEAD`, views |
| `sql/02_journey_funnel.sql` | How many customers reach the 2nd, 3rd ... purchase? Which step loses most? | CTEs, `FILTER`, `LAG`, `FIRST_VALUE` |
| `sql/03_cohort_retention.sql` | What share of each monthly cohort comes back in month 1, 2, 3 ...? | CTEs, `date_trunc`, joins |
| `sql/04_return_rates_30_60_90.sql` | Who returns within 30/60/90 days of their first purchase? | self-join, `BOOL_OR`, fair observation windows |
| `sql/05_segment_comparison.sql` | Do different kinds of new customers come back at different rates? | `NTILE`, `UNION ALL` |
| `sql/06_repeat_timing.sql` | How long do customers wait between purchases, and how many purchases are followed by another within 90 days? | `LAG`, `LEAD` (from the view), `PERCENTILE_CONT`, `FILTER` |

## Cleaning rules (and why)
- Dropped rows with no `CustomerID` (a journey needs an id): 135,080 of 541,909 rows.
- Dropped cancellations (`InvoiceNo` starts with `C`), non-positive quantity or price, and exact duplicate lines.
- **A "purchase" = one customer on one day**, so two invoices an hour apart do not count as a repeat purchase.

## Findings (from the outputs in `outputs/`)
1. **The biggest drop-off is right after the first purchase.** 100% of customers make a 1st purchase, **64.3%** make a 2nd (35.7% lost). Each later step loses less: 31.3%, 26.1%, 27.5%, 22.1%. Only 18.4% reach a 6th purchase. (`outputs/funnel.png`)
2. **Cohorts differ.** The Dec-2010 cohort returned 57.9% within 90 days, while the May-2011 cohort returned 33.1%. (`outputs/cohort_retention.png`, `outputs/04_return_rates_30_60_90.csv`)
3. **First basket size predicts return.** Customers in the top quartile of first-purchase value returned within 90 days **55.6%** of the time versus **35.8%** for the lowest quartile, about 20 percentage points higher. (`outputs/segment_comparison.png`)
4. UK customers returned at 45.0% versus 50.1% for the rest of the world (335 non-UK customers, so treat it as a weak signal).
5. **Timing:** the median wait before a 2nd purchase is 57 days (p90: 192 days). Only 45.5% of first purchases are followed by another purchase within 90 days; for 5th purchases it is 90.3%, so people who keep coming back keep coming back. (`outputs/06_repeat_timing.csv`)

**Suggested recommendation:** put retention effort (a follow-up offer, reminder or reorder prompt) in the days after the *first* purchase, and treat small first baskets as the higher-risk group.

## Limitations
- This is **observational data**. "Bigger first basket, higher return" is a correlation, not proof that discounts or basket size cause retention.
- The dataset has **no discount or acquisition-channel field**, so I segmented by first-basket value and by market instead.
- The final month of each cohort row in the heatmap is a **partial month** (the data ends on 9 Dec 2011), so those cells read low.
- The customers are largely wholesale buyers, so patterns may not match a consumer shop.

## Credit
The project idea and the analysis structure (revenue, cohort and customer-behaviour questions on the Online Retail data) were inspired by
[rahmasayed18/ecommerce-product-analytics](https://github.com/rahmasayed18/ecommerce-product-analytics) (MIT license), which uses MySQL.
All SQL and Python here is rewritten for Postgres with a focus on the funnel and cohort questions.

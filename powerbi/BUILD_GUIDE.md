# Power BI build guide (about 60-90 minutes)

All data cleaning and analysis is already done by the SQL pipeline. This guide turns the outputs into the
interactive report. Power BI Desktop is Windows-only, so the `.pbix` file is built on your machine.

## 1. Load the data (5 min)
Home > Get data > Text/CSV. From `data/processed/` load:

| File | Use |
|---|---|
| `fact_customers.csv` | Main table, one row per customer (24,000) |
| `rpt_risk_tiers.csv` | Ready-made tier table incl. cumulative gains (for the gains chart) |
| `rpt_segment_scorecard.csv` | Segment table with confidence intervals and a "usable for decisions" flag |
| `rpt_tier_by_limit.csv` | Tier x credit-limit matrix |

In Power Query check types: `defaulted`, `risk_tier_rank` = Whole number; amounts = Decimal. Close & Apply.

## 2. Model (5 min)
- No relationships are needed; the report tables are standalone.
- Sort `risk_tier` by `risk_tier_rank`. Hide technical columns (`risk_tier_rank`, `latest_status_code`, `status_m*`, `bill_*`, `payment_*`).

## 3. Measures (10 min)
Empty table `_Measures`, paste everything from `measures.dax`. Create the What-if parameter "Watchlist Depth" (1 to 4, step 1, default 3).
Format rates as %, balances to 1 decimal, `Lift` to 2 decimals.

## 4. Theme
View > Themes > Browse for themes > `theme.json`.

## 5. Pages

**Page 1: Portfolio overview. "How big is the problem?"**
- Cards: `Customers`, `Defaulters`, `Default Rate %`, `Balance Outstanding (NT$m)`, `Defaulted Balance (NT$m)`.
- Column chart: axis `latest_status`, values `Default Rate %`, constant line at the portfolio rate. This is the key chart: it shows the cliff at "2 months late".
- Slicers: `limit_band`, `age_band`.

**Page 2: Early-warning watch-list. "Who do we call first?"**
- Table from `rpt_risk_tiers`: tier, rule, customers, default_rate_pct, share_of_customers_pct, share_of_defaulters_pct, lift.
- Line/scatter chart: x `cum_customers_pct`, y `cum_defaulters_pct` (add a diagonal reference line, 0-100) = gains curve.
- What-if: slicer `Watchlist Depth`, cards `Customers on Watchlist`, `Watchlist Size %`, `Defaulters Caught %`, `Watchlist Precision %`, `Watchlist Lift`, and the `Headline` text in a text card.

**Page 3: Drivers. "What else predicts default?"**
- Field parameter (Modeling > New parameter > Fields): `limit_band`, `utilisation_band`, `months_late_prior5`, `age_band`, `education`, `latest_status`. Slicer "Segment by".
- Bar chart: axis = field parameter, values `Default Rate %`, error bars from `Default CI Low` / `Default CI High`.
- Table with `Customers`, `Default Rate %`, `Lift`, `Share of Defaulters %`.

**Page 4: Limits and fairness**
- Matrix: rows `risk_tier`, columns `limit_band`, values `Default Rate %` with colour scale (from `rpt_tier_by_limit`).
- Table from `rpt_segment_scorecard` filtered to `dimension` in (Sex, Marital status, Age band, Education) showing `usable_for_decisions`. Add a text box: *"Shown for fairness monitoring only. These attributes are not used in the risk rules."*

**Page 5: Recommendations**: text boxes with the numbered recommendations and their supporting numbers (copy from the README).

## 6. Polish checklist
- Page titles state the question, not the chart type. One accent colour for risk, one neutral.
- Alt text on all visuals; check the mobile layout for Page 1.
- Screenshot each page to `images/powerbi_page1.png`... and link them in the README.
- Save the `.pbix` in `powerbi/` and also export a PDF.

## Sanity checks: your report should match
| Check | Expected |
|---|---|
| Customers | 24,000 |
| Defaulters / Default Rate % | 5,306 / 22.1% |
| Balance Outstanding / Defaulted Balance | NT$1,227.1m / NT$258.4m |
| Tier A: customers, default rate | 2,485, 69.9% |
| Watchlist Depth = 3 | 27.1% of customers, 58.6% of defaulters caught |

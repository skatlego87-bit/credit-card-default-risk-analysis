# Data dictionary: `fact_customers`

One row per credit-card customer (24,000). Monthly data **April to September 2005**; the outcome is default in the **following month (October)**.
Amounts are in New Taiwan dollars (NT$). Source columns are renamed so that **1 = most recent month (September)** and **6 = oldest (April)**.

| Column | Description |
|---|---|
| customer_id | Row number in the source file (no customer ID exists) |
| limit_bal / limit_band | Credit limit (NT$) and band |
| age / age_band | Age and band |
| sex, marital_status, education | Demographics. **Kept for description and fairness monitoring only, not used in risk rules.** Education codes 0/5/6 and marital code 0 are undefined in the source and labelled "Unknown" |
| latest_status_code / latest_status | Repayment status last month: -2 no consumption, -1 paid in full, 0 revolving credit and on time, 1 = one month late, 2 = two months late ... 8 = eight months |
| months_late_prior5 | Count of the 5 earlier months with status >= 1 (in practice 2+ months late; see README data-quality finding) |
| worst_status_6m | Worst status across all six months |
| paid_nothing_last_month | 1 if the customer had a prior balance and paid NT$0 last month |
| payment_ratio | Last month's payment / previous month's bill |
| utilisation_pct / utilisation_band | Last bill (floored at 0) as % of credit limit |
| in_credit_last_month | 1 if last bill was negative (customer overpaid) |
| balance_outstanding | Last bill, floored at 0 |
| avg_bill_6m | Average monthly bill |
| status_m1..m6, bill_1..6, payment_1..6 | Full monthly history (1 = Sept ... 6 = Apr) |
| risk_tier / risk_tier_rank | A Critical, B High, C Elevated, D Standard (see README) |
| defaulted / outcome_label | **Outcome**: defaulted next month |
| defaulted_balance | balance_outstanding if defaulted, else 0 (a proxy for exposure, not for loss) |

# Report tables (`rpt_*`)
| Table | Answers |
|---|---|
| rpt_portfolio_summary | Size of the problem: customers, default rate, balances |
| rpt_latest_status | Default rate by latest repayment status |
| rpt_risk_tiers | Early-warning tiers with cumulative capture and lift |
| rpt_tier_stability | Tier default rates on two random halves of the data |
| rpt_tier_by_limit | Tier x credit-limit band |
| rpt_segment_scorecard | Every segment: default rate, shares, lift, 95% interval, whether it is appropriate to use for decisions |
| rpt_status_coding_check | Evidence of the inconsistent "1 month late" coding |

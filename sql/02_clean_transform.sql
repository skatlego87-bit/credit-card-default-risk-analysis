-- =====================================================================
-- 02_clean_transform.sql
-- Builds one analysis-ready table: fact_customers (one row per customer).
--
-- Time frame (per the dataset's documentation): monthly data April-Sept 2005
-- for credit-card holders of a Taiwanese bank. pay_1/bill_amt1/pay_amt1 are the
-- MOST RECENT month (September), pay_6/bill_amt6/pay_amt6 the oldest (April).
-- The outcome is whether the customer defaulted the FOLLOWING month (October).
-- Amounts are in New Taiwan dollars (NT$), not rands.
--
-- Cleaning decisions (see docs/data_dictionary.md and README):
--   1. Duplicates: 24 rows are exact copies, but with no customer ID most are
--      all-zero-activity profiles that are plausibly different people.
--      KEPT and flagged (a check query reports them), not silently deleted.
--   2. Undocumented codes: education 0/5/6 and marriage 0 are not defined in the
--      data description -> relabelled 'Unknown', not guessed.
--   3. Repayment status codes -2 / -1 / 0 are undocumented in the file but are
--      documented by the dataset authors: -2 no consumption, -1 paid in full,
--      0 revolving credit in use, 1+ = months of payment delay. Relabelled.
--   4. Negative bill amounts are customers in credit (overpaid). KEPT; for
--      balance/exposure measures they are floored at zero.
--   5. Status "1 month late" is coded almost only in the latest month (check 8).
--      So "months late" history effectively counts months 2+ late.
--   6. Derived behaviour fields and rule-based risk tiers (no demographics used).
-- =====================================================================
DROP TABLE IF EXISTS fact_customers;

CREATE TABLE fact_customers AS
WITH typed AS (
    SELECT
        row_id AS customer_id,
        CAST(limit_bal AS INTEGER) AS limit_bal,
        CAST(sex AS INTEGER) AS sex_code,
        CAST(education AS INTEGER) AS education_code,
        CAST(marriage AS INTEGER) AS marriage_code,
        CAST(age AS INTEGER) AS age,
        CAST(pay_1 AS INTEGER) AS pay_1, CAST(pay_2 AS INTEGER) AS pay_2, CAST(pay_3 AS INTEGER) AS pay_3,
        CAST(pay_4 AS INTEGER) AS pay_4, CAST(pay_5 AS INTEGER) AS pay_5, CAST(pay_6 AS INTEGER) AS pay_6,
        CAST(bill_amt1 AS REAL) AS bill_1, CAST(bill_amt2 AS REAL) AS bill_2, CAST(bill_amt3 AS REAL) AS bill_3,
        CAST(bill_amt4 AS REAL) AS bill_4, CAST(bill_amt5 AS REAL) AS bill_5, CAST(bill_amt6 AS REAL) AS bill_6,
        CAST(pay_amt1 AS REAL) AS payment_1, CAST(pay_amt2 AS REAL) AS payment_2, CAST(pay_amt3 AS REAL) AS payment_3,
        CAST(pay_amt4 AS REAL) AS payment_4, CAST(pay_amt5 AS REAL) AS payment_5, CAST(pay_amt6 AS REAL) AS payment_6,
        CAST(default_next_month AS INTEGER) AS defaulted
    FROM stg_credit_raw
),
feat AS (
    SELECT t.*,
        MAX(bill_1, 0) AS balance_outstanding,
        (pay_2 >= 1) + (pay_3 >= 1) + (pay_4 >= 1) + (pay_5 >= 1) + (pay_6 >= 1) AS months_late_prior5,
        MAX(pay_1, pay_2, pay_3, pay_4, pay_5, pay_6) AS worst_status_6m,
        CASE WHEN payment_1 = 0 AND bill_2 > 0 THEN 1 ELSE 0 END AS paid_nothing_last_month,
        CASE WHEN bill_2 > 0 THEN ROUND(payment_1 / bill_2, 3) END AS payment_ratio,
        ROUND(100.0 * MAX(bill_1, 0) / limit_bal, 1) AS utilisation_pct
    FROM typed t
)
SELECT
    customer_id,
    limit_bal,
    CASE WHEN limit_bal <  50000 THEN '1. Under 50k'
         WHEN limit_bal < 100000 THEN '2. 50k-100k'
         WHEN limit_bal < 200000 THEN '3. 100k-200k'
         WHEN limit_bal < 400000 THEN '4. 200k-400k'
         ELSE                         '5. 400k+' END AS limit_band,
    age,
    CASE WHEN age < 25 THEN '1. Under 25' WHEN age < 35 THEN '2. 25-34' WHEN age < 45 THEN '3. 35-44'
         WHEN age < 55 THEN '4. 45-54'    ELSE '5. 55+' END AS age_band,
    -- demographics: kept for description and fairness checks only, NOT for risk rules
    CASE sex_code WHEN 1 THEN 'Male' WHEN 2 THEN 'Female' END AS sex,
    CASE education_code WHEN 1 THEN 'Graduate school' WHEN 2 THEN 'University' WHEN 3 THEN 'High school'
                        WHEN 4 THEN 'Other' ELSE 'Unknown' END AS education,
    CASE marriage_code WHEN 1 THEN 'Married' WHEN 2 THEN 'Single' WHEN 3 THEN 'Other' ELSE 'Unknown' END AS marital_status,

    -- repayment behaviour
    pay_1 AS latest_status_code,
    CASE WHEN pay_1 = -2 THEN '1. No consumption'
         WHEN pay_1 = -1 THEN '2. Paid in full'
         WHEN pay_1 =  0 THEN '3. Revolving, on time'
         WHEN pay_1 =  1 THEN '4. 1 month late'
         WHEN pay_1 =  2 THEN '5. 2 months late'
         ELSE                 '6. 3+ months late' END AS latest_status,
    months_late_prior5,
    worst_status_6m,
    paid_nothing_last_month,
    payment_ratio,
    utilisation_pct,
    CASE WHEN utilisation_pct <= 20 THEN '1. 0-20%'  WHEN utilisation_pct <= 50 THEN '2. 20-50%'
         WHEN utilisation_pct <= 80 THEN '3. 50-80%' WHEN utilisation_pct <= 100 THEN '4. 80-100%'
         ELSE '5. Over limit' END AS utilisation_band,
    CASE WHEN bill_1 < 0 THEN 1 ELSE 0 END AS in_credit_last_month,
    balance_outstanding,
    ROUND((bill_1 + bill_2 + bill_3 + bill_4 + bill_5 + bill_6) / 6.0, 0) AS avg_bill_6m,

    -- full monthly detail for Power BI drill-through (1 = Sept 2005 ... 6 = Apr 2005)
    pay_1 AS status_m1, pay_2 AS status_m2, pay_3 AS status_m3, pay_4 AS status_m4, pay_5 AS status_m5, pay_6 AS status_m6,
    bill_1, bill_2, bill_3, bill_4, bill_5, bill_6,
    payment_1, payment_2, payment_3, payment_4, payment_5, payment_6,

    -- rule-based early-warning tier (behaviour only; no sex, marital status or education)
    CASE WHEN pay_1 >= 2                                            THEN 'A. Critical'
         WHEN pay_1 =  1                                            THEN 'B. High'
         WHEN months_late_prior5 >= 2 OR paid_nothing_last_month = 1 THEN 'C. Elevated'
         ELSE                                                            'D. Standard' END AS risk_tier,
    CASE WHEN pay_1 >= 2 THEN 1 WHEN pay_1 = 1 THEN 2
         WHEN months_late_prior5 >= 2 OR paid_nothing_last_month = 1 THEN 3 ELSE 4 END AS risk_tier_rank,

    -- outcome
    defaulted,
    CASE defaulted WHEN 1 THEN 'Defaulted' ELSE 'Paid' END AS outcome_label,
    CASE WHEN defaulted = 1 THEN balance_outstanding ELSE 0 END AS defaulted_balance
FROM feat;

CREATE INDEX idx_fc_tier ON fact_customers(risk_tier);
CREATE INDEX idx_fc_status ON fact_customers(latest_status_code);

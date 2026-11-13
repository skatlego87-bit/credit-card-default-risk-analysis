-- =====================================================================
-- 04_analysis_tables.sql  -  report tables (rpt_*) that answer the business questions
-- =====================================================================

-- Q1. How big is the problem? Customers and balances.
DROP TABLE IF EXISTS rpt_portfolio_summary;
CREATE TABLE rpt_portfolio_summary AS
SELECT COUNT(*)                                                  AS customers,
       SUM(defaulted)                                            AS defaulters,
       ROUND(100.0 * AVG(defaulted), 2)                          AS default_rate_pct,
       ROUND(SUM(balance_outstanding) / 1e6, 1)                  AS balance_outstanding_m,
       ROUND(SUM(defaulted_balance) / 1e6, 1)                    AS defaulted_balance_m,
       ROUND(100.0 * SUM(defaulted_balance) / SUM(balance_outstanding), 2) AS balance_weighted_default_pct,
       ROUND(AVG(limit_bal), 0)                                  AS avg_limit
FROM fact_customers;

-- Q2. How early can we see it? Default rate by latest repayment status.
DROP TABLE IF EXISTS rpt_latest_status;
CREATE TABLE rpt_latest_status AS
SELECT latest_status,
       COUNT(*)                                          AS customers,
       SUM(defaulted)                                    AS defaulters,
       ROUND(100.0 * AVG(defaulted), 1)                  AS default_rate_pct,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM fact_customers), 1) AS share_of_customers_pct,
       ROUND(100.0 * SUM(defaulted) / (SELECT SUM(defaulted) FROM fact_customers), 1) AS share_of_defaulters_pct
FROM fact_customers GROUP BY latest_status;

-- Q3. Early-warning tiers: how many defaulters would a watch-list catch?
DROP TABLE IF EXISTS rpt_risk_tiers;
CREATE TABLE rpt_risk_tiers AS
WITH t AS (
    SELECT risk_tier, risk_tier_rank,
           COUNT(*) AS customers, SUM(defaulted) AS defaulters,
           SUM(balance_outstanding) AS balance, SUM(defaulted_balance) AS defaulted_balance
    FROM fact_customers GROUP BY risk_tier, risk_tier_rank
), tot AS (
    SELECT COUNT(*) AS n, SUM(defaulted) AS d, SUM(balance_outstanding) AS b FROM fact_customers
)
SELECT risk_tier,
       CASE risk_tier WHEN 'A. Critical' THEN '2+ months late last month'
                      WHEN 'B. High'     THEN '1 month late last month'
                      WHEN 'C. Elevated' THEN 'Not late now, but 2+ earlier late months OR paid nothing last month'
                      ELSE 'None of the above' END                         AS rule,
       customers, defaulters,
       ROUND(100.0 * defaulters / customers, 1)                            AS default_rate_pct,
       ROUND(100.0 * customers / tot.n, 1)                                 AS share_of_customers_pct,
       ROUND(100.0 * defaulters / tot.d, 1)                                AS share_of_defaulters_pct,
       ROUND(100.0 * SUM(customers) OVER (ORDER BY risk_tier_rank) / tot.n, 1) AS cum_customers_pct,
       ROUND(100.0 * SUM(defaulters) OVER (ORDER BY risk_tier_rank) / tot.d, 1) AS cum_defaulters_pct,
       ROUND((1.0 * defaulters / customers) / (1.0 * tot.d / tot.n), 2)    AS lift,
       ROUND(balance / 1e6, 1)                                             AS balance_m,
       ROUND(defaulted_balance / 1e6, 1)                                   AS defaulted_balance_m,
       ROUND(100.0 * balance / tot.b, 1)                                   AS share_of_balance_pct
FROM t, tot ORDER BY risk_tier_rank;

-- Q3b. Stability check: do the tiers behave the same on two random halves (odd/even customer ids)?
DROP TABLE IF EXISTS rpt_tier_stability;
CREATE TABLE rpt_tier_stability AS
SELECT risk_tier,
       CASE WHEN customer_id % 2 = 0 THEN 'Half 1 (even ids)' ELSE 'Half 2 (odd ids)' END AS sample_half,
       COUNT(*) AS customers,
       ROUND(100.0 * AVG(defaulted), 1) AS default_rate_pct
FROM fact_customers GROUP BY 1, 2;

-- Q4. Does credit limit change the picture inside each tier?
DROP TABLE IF EXISTS rpt_tier_by_limit;
CREATE TABLE rpt_tier_by_limit AS
SELECT risk_tier, limit_band, COUNT(*) AS customers,
       ROUND(100.0 * AVG(defaulted), 1) AS default_rate_pct
FROM fact_customers GROUP BY risk_tier, limit_band;

-- Q5. Segment scorecard with 95% Wilson interval and lift.
-- usable_for_decisions flags attributes a lender should not use to decide credit.
DROP TABLE IF EXISTS rpt_segment_scorecard;
CREATE TABLE rpt_segment_scorecard AS
WITH base AS (
    SELECT 'Latest repayment status' AS dimension, latest_status AS segment, 'Yes' AS usable_for_decisions, defaulted, balance_outstanding FROM fact_customers
    UNION ALL SELECT 'Late months before latest (0-5)', CAST(months_late_prior5 AS TEXT), 'Yes', defaulted, balance_outstanding FROM fact_customers
    UNION ALL SELECT 'Paid nothing last month', CASE paid_nothing_last_month WHEN 1 THEN 'Yes (had a balance)' ELSE 'No' END, 'Yes', defaulted, balance_outstanding FROM fact_customers
    UNION ALL SELECT 'Credit limit band', limit_band, 'Yes', defaulted, balance_outstanding FROM fact_customers
    UNION ALL SELECT 'Credit utilisation', utilisation_band, 'Yes', defaulted, balance_outstanding FROM fact_customers
    UNION ALL SELECT 'Age band', age_band, 'Use with care: restricted in some jurisdictions', defaulted, balance_outstanding FROM fact_customers
    UNION ALL SELECT 'Education', education, 'Use with care: can act as a proxy', defaulted, balance_outstanding FROM fact_customers
    UNION ALL SELECT 'Marital status', marital_status, 'No: protected characteristic in many jurisdictions', defaulted, balance_outstanding FROM fact_customers
    UNION ALL SELECT 'Sex', sex, 'No: protected characteristic in many jurisdictions', defaulted, balance_outstanding FROM fact_customers
), agg AS (
    SELECT dimension, segment, usable_for_decisions,
           COUNT(*) AS customers, SUM(defaulted) AS defaulters,
           SUM(balance_outstanding) AS balance
    FROM base GROUP BY dimension, segment, usable_for_decisions
), tot AS (SELECT COUNT(*) AS n, SUM(defaulted) AS d FROM fact_customers)
SELECT dimension, segment, usable_for_decisions, customers, defaulters,
       ROUND(100.0 * defaulters / customers, 2)                 AS default_rate_pct,
       ROUND(100.0 * customers / tot.n, 2)                      AS share_of_customers_pct,
       ROUND(100.0 * defaulters / tot.d, 2)                     AS share_of_defaulters_pct,
       ROUND((1.0 * defaulters / customers) / (1.0 * tot.d / tot.n), 2) AS lift,
       ROUND(balance / 1e6, 1)                                  AS balance_m,
       ROUND(100.0 * ((p + 1.96*1.96/(2*nn)) - 1.96 * SQRT(p*(1-p)/nn + 1.96*1.96/(4*nn*nn))) / (1 + 1.96*1.96/nn), 2) AS ci_low_pct,
       ROUND(100.0 * ((p + 1.96*1.96/(2*nn)) + 1.96 * SQRT(p*(1-p)/nn + 1.96*1.96/(4*nn*nn))) / (1 + 1.96*1.96/nn), 2) AS ci_high_pct
FROM (SELECT *, 1.0 * defaulters / customers AS p, 1.0 * customers AS nn FROM agg), tot;

-- Q6. Data-coding finding made visible: how often each status code appears, by month.
DROP TABLE IF EXISTS rpt_status_coding_check;
CREATE TABLE rpt_status_coding_check AS
SELECT 'Latest (Sep)' AS month_label, 1 AS month_order, SUM(status_m1 = 1) AS one_month_late, SUM(status_m1 = 2) AS two_months_late FROM fact_customers
UNION ALL SELECT 'Aug', 2, SUM(status_m2 = 1), SUM(status_m2 = 2) FROM fact_customers
UNION ALL SELECT 'Jul', 3, SUM(status_m3 = 1), SUM(status_m3 = 2) FROM fact_customers
UNION ALL SELECT 'Jun', 4, SUM(status_m4 = 1), SUM(status_m4 = 2) FROM fact_customers
UNION ALL SELECT 'May', 5, SUM(status_m5 = 1), SUM(status_m5 = 2) FROM fact_customers
UNION ALL SELECT 'Apr', 6, SUM(status_m6 = 1), SUM(status_m6 = 2) FROM fact_customers;

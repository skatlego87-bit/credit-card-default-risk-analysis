-- =====================================================================
-- 03_data_quality_checks.sql  (run after 02; expected results in comments)
-- =====================================================================

-- 1. Row reconciliation raw vs clean (expect 0 difference: nothing is dropped)
SELECT (SELECT COUNT(*) FROM stg_credit_raw) - (SELECT COUNT(*) FROM fact_customers) AS rows_dropped;

-- 2. Unique key (expect 0)
SELECT COUNT(*) - COUNT(DISTINCT customer_id) AS duplicate_ids FROM fact_customers;

-- 3. No NULLs in core fields (expect 0)
SELECT COUNT(*) FROM fact_customers
WHERE limit_bal IS NULL OR age IS NULL OR latest_status_code IS NULL OR defaulted IS NULL OR bill_1 IS NULL;

-- 4. Ranges (expect limit 10,000-1,000,000; age 21-79; defaulted only 0/1)
SELECT MIN(limit_bal), MAX(limit_bal), MIN(age), MAX(age), MIN(defaulted), MAX(defaulted) FROM fact_customers;

-- 5. Repayment status codes all within the documented range -2..8 (expect 0)
SELECT COUNT(*) FROM fact_customers
WHERE status_m1 NOT BETWEEN -2 AND 8 OR status_m2 NOT BETWEEN -2 AND 8 OR status_m3 NOT BETWEEN -2 AND 8
   OR status_m4 NOT BETWEEN -2 AND 8 OR status_m5 NOT BETWEEN -2 AND 8 OR status_m6 NOT BETWEEN -2 AND 8;

-- 6. FINDING: undocumented demographic codes relabelled Unknown (education 0/5/6 and marriage 0)
SELECT SUM(education = 'Unknown') AS education_unknown, SUM(marital_status = 'Unknown') AS marital_unknown FROM fact_customers;

-- 7. FINDING: customers in credit (negative bill) last month, kept and floored at 0 for balances
SELECT SUM(in_credit_last_month) AS in_credit_last_month FROM fact_customers;

-- 8. FINDING: status "1 month late" is coded 2,907 times in the latest month but almost never earlier.
--    Earlier-month history therefore effectively means 2+ months late.
SELECT SUM(status_m1 = 1) AS m1, SUM(status_m2 = 1) AS m2, SUM(status_m3 = 1) AS m3,
       SUM(status_m4 = 1) AS m4, SUM(status_m5 = 1) AS m5, SUM(status_m6 = 1) AS m6 FROM fact_customers;

-- 9. FINDING: exact duplicate rows (no customer ID, so they are kept; 87% are zero-activity profiles)
SELECT COALESCE(SUM(c - 1), 0) AS extra_duplicate_rows FROM (
    SELECT COUNT(*) AS c FROM stg_credit_raw
    GROUP BY limit_bal, sex, education, marriage, age, pay_1, pay_2, pay_3, pay_4, pay_5, pay_6,
             bill_amt1, bill_amt2, bill_amt3, bill_amt4, bill_amt5, bill_amt6,
             pay_amt1, pay_amt2, pay_amt3, pay_amt4, pay_amt5, pay_amt6, default_next_month
    HAVING COUNT(*) > 1);

-- 10. Overall default rate sanity check (expect about 22.1%)
SELECT ROUND(100.0 * AVG(defaulted), 2) AS default_rate_pct FROM fact_customers;

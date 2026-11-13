-- =====================================================================
-- 01_staging.sql
-- Raw landing table: everything stays TEXT and untouched so the cleaned
-- data can always be reconciled to the source file.
-- row_id = position in the original file (the file has no customer ID).
-- =====================================================================
DROP TABLE IF EXISTS stg_credit_raw;

CREATE TABLE stg_credit_raw (
    row_id      INTEGER PRIMARY KEY,
    limit_bal   TEXT,
    sex         TEXT,
    education   TEXT,
    marriage    TEXT,
    age         TEXT,
    pay_1 TEXT, pay_2 TEXT, pay_3 TEXT, pay_4 TEXT, pay_5 TEXT, pay_6 TEXT,
    bill_amt1 TEXT, bill_amt2 TEXT, bill_amt3 TEXT, bill_amt4 TEXT, bill_amt5 TEXT, bill_amt6 TEXT,
    pay_amt1 TEXT, pay_amt2 TEXT, pay_amt3 TEXT, pay_amt4 TEXT, pay_amt5 TEXT, pay_amt6 TEXT,
    default_next_month TEXT
);

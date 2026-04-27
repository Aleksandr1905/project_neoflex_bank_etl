TRUNCATE TABLE DS.FT_POSTING_F;

INSERT INTO DS.FT_POSTING_F (oper_date, credit_account_rk, debet_account_rk, credit_amount, debet_amount)
SELECT
    TO_DATE(oper_date, 'DD-MM-YYYY'),
    credit_account_rk::INTEGER,
    debet_account_rk::INTEGER,
    credit_amount::NUMERIC,
    debet_amount::NUMERIC
FROM RAW.FT_POSTING_F;
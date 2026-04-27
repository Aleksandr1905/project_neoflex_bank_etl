INSERT INTO DS.FT_BALANCE_F (on_date, account_rk, currency_rk, balance_out)
SELECT
    TO_DATE(on_date, 'DD.MM.YYYY'),
    account_rk::INTEGER,
    currency_rk::INTEGER,
    balance_out::NUMERIC
FROM RAW.FT_BALANCE_F
ON CONFLICT (on_date, account_rk)
DO UPDATE SET
    currency_rk = EXCLUDED.currency_rk,
    balance_out = EXCLUDED.balance_out;
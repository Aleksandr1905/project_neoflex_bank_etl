INSERT INTO DS.MD_ACCOUNT_D (data_actual_date, data_actual_end_date, account_rk, account_number, char_type, currency_rk, currency_code)
SELECT
    data_actual_date::DATE,
    data_actual_end_date::DATE,
    account_rk::INTEGER,
    account_number::VARCHAR(20),
    char_type::VARCHAR(1),
    currency_rk::INTEGER,
    currency_code::VARCHAR(3)
FROM RAW.MD_ACCOUNT_D
ON CONFLICT (data_actual_date, account_rk)
DO UPDATE SET
    data_actual_end_date = EXCLUDED.data_actual_end_date,
    account_number = EXCLUDED.account_number,
    char_type = EXCLUDED.char_type,
    currency_rk = EXCLUDED.currency_rk,
    currency_code = EXCLUDED.currency_code;
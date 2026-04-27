INSERT INTO DS.MD_CURRENCY_D (currency_rk, data_actual_date, data_actual_end_date, currency_code, code_iso_char)
SELECT
    currency_rk::INTEGER,
    data_actual_date::DATE,
    data_actual_end_date::DATE,
    NULLIF(TRIM(currency_code), '')::VARCHAR(3),
    NULLIF(REGEXP_REPLACE(code_iso_char, '[^A-Z]', '', 'g'), '')::VARCHAR(3)
FROM RAW.MD_CURRENCY_D
ON CONFLICT (currency_rk, data_actual_date)
DO UPDATE SET
    data_actual_end_date = EXCLUDED.data_actual_end_date,
    currency_code = EXCLUDED.currency_code,
    code_iso_char = EXCLUDED.code_iso_char;
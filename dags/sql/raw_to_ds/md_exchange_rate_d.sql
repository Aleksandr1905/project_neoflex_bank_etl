INSERT INTO DS.MD_EXCHANGE_RATE_D (data_actual_date, data_actual_end_date, currency_rk, reduced_cource, code_iso_num)
SELECT DISTINCT ON (data_actual_date, currency_rk)
    data_actual_date::DATE,
    data_actual_end_date::DATE,
    currency_rk::INTEGER,
    reduced_cource::NUMERIC,
    code_iso_num::VARCHAR(3)
FROM RAW.MD_EXCHANGE_RATE_D
ON CONFLICT (data_actual_date, currency_rk)
DO UPDATE SET
    data_actual_end_date = EXCLUDED.data_actual_end_date,
    reduced_cource = EXCLUDED.reduced_cource,
    code_iso_num = EXCLUDED.code_iso_num;
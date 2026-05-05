
-- ============================================
-- 1. ACCOUNT TURNOVER
-- Рассчитывает обороты по счетам за день
-- ============================================
CREATE OR REPLACE PROCEDURE ds.fill_account_turnover_f(i_OnDate DATE)
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows_affected INTEGER;
    v_log_id INTEGER;
BEGIN

    INSERT INTO logs.etl_log (process_name, step_name, status, start_time, details)
    VALUES ('ds_to_dm', 'load_dm_account_balance_f', 'STARTED', CURRENT_TIMESTAMP,
            jsonb_build_object('on_date', i_OnDate::TEXT))
    RETURNING log_id INTO v_log_id;

    DELETE FROM dm.dm_account_turnover_f WHERE on_date = i_OnDate;

    WITH
    debit_turnover AS (
        SELECT
            debet_account_rk AS account_rk
            , SUM(debet_amount) AS debet_sum
        FROM ds.ft_posting_f
        WHERE oper_date = i_OnDate
        GROUP BY debet_account_rk
    ),
    credit_turnover AS (
        SELECT
            credit_account_rk AS account_rk
            , SUM(credit_amount) AS credit_sum
        FROM ds.ft_posting_f
        WHERE oper_date = i_OnDate
        GROUP BY credit_account_rk
    ),
    all_accounts AS (
        SELECT
            COALESCE(deb.account_rk, cre.account_rk) AS account_rk,
            COALESCE(cre.credit_sum, 0) AS credit_amount,
            COALESCE(deb.debet_sum, 0) AS debet_amount
        FROM debit_turnover AS deb
        FULL JOIN credit_turnover AS cre ON deb.account_rk = cre.account_rk
    )
    INSERT INTO dm.dm_account_turnover_f (on_date, account_rk, credit_amount, credit_amount_rub, debet_amount, debet_amount_rub)
    SELECT
        i_OnDate
        , ala.account_rk
        , ala.credit_amount
        , ala.credit_amount * COALESCE(exr.reduced_cource, 1)
        , ala.debet_amount
        , ala.debet_amount * COALESCE(exr.reduced_cource, 1)
    FROM all_accounts AS ala
    LEFT JOIN ds.md_account_d AS acc ON ala.account_rk = acc.account_rk
        AND i_OnDate BETWEEN acc.data_actual_date AND COALESCE(acc.data_actual_end_date, '2999-12-31')
    LEFT JOIN ds.md_exchange_rate_d AS exr ON exr.currency_rk = acc.currency_rk
        AND i_OnDate BETWEEN exr.data_actual_date AND COALESCE(exr.data_actual_end_date, '2999-12-31');

    SELECT COUNT(*) INTO v_rows_affected
    FROM dm.dm_account_turnover_f
    WHERE on_date = i_OnDate;

    UPDATE logs.etl_log
    SET status = 'SUCCESS',
        end_time = CURRENT_TIMESTAMP,
        rows_affected = v_rows_affected
    WHERE log_id = v_log_id;


EXCEPTION WHEN OTHERS THEN

    UPDATE logs.etl_log
    SET status = 'FAILED',
        error_affected = SQLERRM,
        end_time = CURRENT_TIMESTAMP
    WHERE log_id = v_log_id;

    RAISE;
END;
$$;


-- ============================================
-- 2. INIT BALANCE
-- Заполняет начальные остатки на 31.12.2017
-- ============================================


CREATE OR REPLACE PROCEDURE ds.init_balance_f()
LANGUAGE plpgsql
AS $$
DECLARE
    v_init_date DATE := '2017-12-31';
    v_rows_affected INTEGER;
    v_log_id INTEGER;
BEGIN
    INSERT INTO logs.etl_log (process_name, step_name, status, start_time, details)
    VALUES ('ds_to_dm', 'init_dm_account_balance_f', 'STARTED', CURRENT_TIMESTAMP,
            jsonb_build_object('init_date', v_init_date::TEXT))
    RETURNING log_id INTO v_log_id;

    DELETE FROM dm.dm_account_balance_f WHERE on_date = v_init_date;

    INSERT INTO dm.dm_account_balance_f (on_date, account_rk, balance_out, balance_out_rub)
    SELECT
        v_init_date
        , bal.account_rk
        , bal.balance_out
        , bal.balance_out * COALESCE(exr.reduced_cource, 1)
    FROM ds.ft_balance_f AS bal
    LEFT JOIN ds.md_exchange_rate_d AS exr ON exr.currency_rk = bal.currency_rk
        AND v_init_date BETWEEN exr.data_actual_date AND COALESCE(exr.data_actual_end_date, '2999-12-31')
    WHERE bal.on_date = v_init_date;

    SELECT COUNT(*) INTO v_rows_affected
    FROM dm.dm_account_balance_f
    WHERE on_date = v_init_date;

    UPDATE logs.etl_log
    SET status = 'SUCCESS',
        end_time = CURRENT_TIMESTAMP,
        rows_affected = v_rows_affected
    WHERE log_id = v_log_id;

EXCEPTION WHEN OTHERS THEN
    UPDATE logs.etl_log
    SET status = 'FAILED',
        error_affected = SQLERRM,
        end_time = CURRENT_TIMESTAMP
    WHERE log_id = v_log_id;

    RAISE;
END;
$$;


-- ============================================
-- 3. ACCOUNT BALANCE
-- Рассчитывает остатки по счетам за день
-- ============================================


CREATE OR REPLACE PROCEDURE ds.fill_account_balance_f(i_OnDate DATE)
LANGUAGE plpgsql
AS $$
DECLARE
    v_prev_date DATE := i_OnDate - INTERVAL '1 day';
    v_log_id INTEGER;
    v_rows INTEGER;
BEGIN
    INSERT INTO logs.etl_log (process_name, step_name, status, start_time, details)
    VALUES ('ds_to_dm', 'load_dm_account_turnover_f', 'STARTED', CURRENT_TIMESTAMP,
            jsonb_build_object('on_date', i_OnDate::TEXT))
    RETURNING log_id INTO v_log_id;

    DELETE FROM dm.dm_account_balance_f WHERE on_date = i_OnDate;

    INSERT INTO dm.dm_account_balance_f (on_date, account_rk, balance_out, balance_out_rub)
    SELECT
        i_OnDate,
        a.account_rk,
        CASE a.char_type
            WHEN 'А' THEN COALESCE(b.balance_out, 0) + COALESCE(t.debet_amount, 0) - COALESCE(t.credit_amount, 0)
            WHEN 'П' THEN COALESCE(b.balance_out, 0) - COALESCE(t.debet_amount, 0) + COALESCE(t.credit_amount, 0)
        END,
        CASE a.char_type
            WHEN 'А' THEN COALESCE(b.balance_out_rub, 0) + COALESCE(t.debet_amount_rub, 0) - COALESCE(t.credit_amount_rub, 0)
            WHEN 'П' THEN COALESCE(b.balance_out_rub, 0) - COALESCE(t.debet_amount_rub, 0) + COALESCE(t.credit_amount_rub, 0)
        END
    FROM ds.md_account_d a
    LEFT JOIN dm.dm_account_balance_f b ON b.account_rk = a.account_rk AND b.on_date = v_prev_date
    LEFT JOIN dm.dm_account_turnover_f t ON t.account_rk = a.account_rk AND t.on_date = i_OnDate;

    SELECT COUNT(*) INTO v_rows FROM dm.dm_account_balance_f WHERE on_date = i_OnDate;

    UPDATE logs.etl_log
    SET status = 'SUCCESS', rows_affected = v_rows, end_time = CURRENT_TIMESTAMP
    WHERE log_id = v_log_id;

EXCEPTION WHEN OTHERS THEN
    UPDATE logs.etl_log
    SET status = 'FAILED', error_affected = SQLERRM, end_time = CURRENT_TIMESTAMP
    WHERE log_id = v_log_id;
    RAISE;
END;
$$;

-- ============================================
-- 4. F101
-- Рассчитывает форму 101
-- ============================================


CREATE OR REPLACE PROCEDURE ds.fill_f101_round_f(i_OnDate DATE)
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_date DATE := i_OnDate - INTERVAL '1 month';
    v_to_date DATE := i_OnDate - INTERVAL '1 day';
    v_balance_date DATE := v_from_date - INTERVAL '1 day';
    v_log_id INTEGER;
    v_row_count INTEGER;
BEGIN

    INSERT INTO logs.etl_log (process_name, step_name, status, start_time, details)
    VALUES ('ds_to_dm', 'dm.fill_f101_round_f', 'STARTED', CURRENT_TIMESTAMP,
            jsonb_build_object('i_OnDate', i_OnDate, 'from_date', v_from_date, 'to_date', v_to_date, 'balance_date', v_balance_date))
    RETURNING log_id INTO v_log_id;

    DELETE FROM dm.dm_f101_round_f
    WHERE from_date = v_from_date AND to_date = v_to_date;

    INSERT INTO dm.dm_f101_round_f (
        from_date, to_date, chapter, ledger_account, characteristic,
        balance_in_rub, balance_in_val, balance_in_total,
        turn_deb_rub, turn_deb_val, turn_deb_total,
        turn_cre_rub, turn_cre_val, turn_cre_total,
        balance_out_rub, balance_out_val, balance_out_total
    )
    WITH turnovers AS (
        SELECT
            account_rk,
            SUM(debet_amount_rub) AS debet_sum_rub,
            SUM(credit_amount_rub) AS credit_sum_rub
        FROM dm.dm_account_turnover_f
        WHERE on_date BETWEEN v_from_date AND v_to_date
        GROUP BY account_rk
    )
    SELECT
        v_from_date,
        v_to_date,
        lc.chapter AS chapter,
        LEFT(acc.account_number, 5) AS ledger_account,
        acc.char_type AS characteristic,

        -- Входящие остатки
        COALESCE(SUM(CASE WHEN acc.currency_code IN ('810', '643') THEN bi.balance_out_rub ELSE 0 END), 0) AS balance_in_rub,
        COALESCE(SUM(CASE WHEN acc.currency_code NOT IN ('810', '643') THEN bi.balance_out_rub ELSE 0 END), 0) AS balance_in_val,
        COALESCE(SUM(bi.balance_out_rub), 0) AS balance_in_total,

        -- Дебетовые обороты
        COALESCE(SUM(CASE WHEN acc.currency_code IN ('810', '643') THEN t.debet_sum_rub ELSE 0 END), 0) AS turn_deb_rub,
        COALESCE(SUM(CASE WHEN acc.currency_code NOT IN ('810', '643') THEN t.debet_sum_rub ELSE 0 END), 0) AS turn_deb_val,
        COALESCE(SUM(t.debet_sum_rub), 0) AS turn_deb_total,

        -- Кредитовые обороты
        COALESCE(SUM(CASE WHEN acc.currency_code IN ('810', '643') THEN t.credit_sum_rub ELSE 0 END), 0) AS turn_cre_rub,
        COALESCE(SUM(CASE WHEN acc.currency_code NOT IN ('810', '643') THEN t.credit_sum_rub ELSE 0 END), 0) AS turn_cre_val,
        COALESCE(SUM(t.credit_sum_rub), 0) AS turn_cre_total,

        -- Исходящие остатки
        COALESCE(SUM(CASE WHEN acc.currency_code IN ('810', '643') THEN bo.balance_out_rub ELSE 0 END), 0) AS balance_out_rub,
        COALESCE(SUM(CASE WHEN acc.currency_code NOT IN ('810', '643') THEN bo.balance_out_rub ELSE 0 END), 0) AS balance_out_val,
        COALESCE(SUM(bo.balance_out_rub), 0) AS balance_out_total

    FROM ds.md_account_d acc

    LEFT JOIN dm.dm_account_balance_f bi
        ON bi.account_rk = acc.account_rk
        AND bi.on_date = v_balance_date

    LEFT JOIN dm.dm_account_balance_f bo
        ON bo.account_rk = acc.account_rk
        AND bo.on_date = v_to_date

    LEFT JOIN turnovers t
        ON t.account_rk = acc.account_rk

    LEFT JOIN ds.md_ledger_account_s lc
        ON lc.ledger_account = LEFT(acc.account_number, 5)::INTEGER
        AND lc.start_date <= v_to_date
        AND lc.end_date >= v_from_date

    WHERE acc.data_actual_date <= v_to_date
      AND acc.data_actual_end_date >= v_from_date

    GROUP BY
        LEFT(acc.account_number, 5),
        acc.char_type,
        lc.chapter;

    SELECT COUNT(*) INTO v_row_count
    FROM dm.dm_f101_round_f
    WHERE from_date = v_from_date AND to_date = v_to_date;


    UPDATE logs.etl_log
    SET status = 'SUCCESS',
        end_time = CURRENT_TIMESTAMP,
        rows_affected = v_row_count
    WHERE log_id = v_log_id;

EXCEPTION WHEN OTHERS THEN
    UPDATE logs.etl_log
    SET status = 'FAILED',
        error_affected = SQLERRM,
        end_time = CURRENT_TIMESTAMP
    WHERE log_id = v_log_id;

    RAISE;
END;
$$;
CREATE TABLE IF NOT EXISTS ds.ft_balance_f(
    on_date DATE NOT NULL
    , account_rk INTEGER NOT NULL
    , currency_rk INTEGER
    , balance_out numeric(23, 8)
    , CONSTRAINT pk_ft_balance_f PRIMARY KEY (on_date, account_rk));

CREATE TABLE IF NOT EXISTS ds.ft_posting_f(
    oper_date DATE NOT NULL
    , credit_account_rk INTEGER NOT NULL
    , debet_account_rk INTEGER NOT NULL
    , credit_amount numeric(23,8)
    , debet_amount numeric(23,8)
    );

CREATE TABLE IF NOT EXISTS ds.md_account_d(
    data_actual_date DATE NOT NULL
    , data_actual_end_date DATE NOT NULL
    , account_rk INTEGER NOT NULL
    , account_number VARCHAR(20) NOT NULL
    , char_type VARCHAR(1) NOT NULL
    , currency_rk INTEGER NOT NULL
    , currency_code VARCHAR(20) NOT NULL
    , CONSTRAINT pk_md_account_d PRIMARY KEY (data_actual_date, account_rk));

CREATE TABLE IF NOT EXISTS ds.md_currency_d(
    currency_rk INTEGER NOT NULL
    , data_actual_date DATE NOT NULL
    , data_actual_end_date DATE
    , currency_code VARCHAR(3)
    , code_iso_char VARCHAR(3)
    , CONSTRAINT pk_md_currency_d PRIMARY KEY (currency_rk, data_actual_date));

CREATE TABLE IF NOT EXISTS ds.md_exchange_rate_d(
    data_actual_date DATE NOT NULL
    , data_actual_end_date DATE
    , currency_rk INTEGER NOT NULL
    , reduced_cource numeric(23,8)
    , code_iso_num VARCHAR(3)
    , CONSTRAINT pk_md_exchange_rate_d PRIMARY KEY (data_actual_date, currency_rk));

CREATE TABLE IF NOT EXISTS ds.md_ledger_account_s(
    chapter CHAR(1)
    , chapter_name VARCHAR(16)
    , section_number INTEGER
    , section_name VARCHAR(22)
    , subsection_name VARCHAR(21)
    , ledger1_account INTEGER
    , ledger1_account_name VARCHAR(47)
    , ledger_account INTEGER NOT NULL
    , ledger_account_name VARCHAR(153)
    , characteristic char(1)
    , start_date DATE NOT NULL
    , end_date DATE
    , CONSTRAINT pk_md_ledger_account_s PRIMARY KEY (ledger_account, start_date));
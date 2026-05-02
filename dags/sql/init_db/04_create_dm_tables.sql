CREATE TABLE IF NOT EXISTS DM.DM_ACCOUNT_TURNOVER_F(
    on_date DATE
    , account_rk INTEGER
    , credit_amount numeric(23,8)
    , credit_amount_rub numeric(23,8)
    , debet_amount numeric(23,8)
    , debet_amount_rub numeric(23,8)
    );

CREATE TABLE IF NOT EXISTS DM.DM_ACCOUNT_BALANCE_F(
    on_date DATE
    , account_rk integer
    , balance_out numeric(23,8)
    , balance_out_rub numeric(23,8)
    );
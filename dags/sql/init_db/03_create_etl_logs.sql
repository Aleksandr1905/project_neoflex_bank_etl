CREATE TABLE IF NOT EXISTS logs.etl_log(
    log_id SERIAL PRIMARY KEY
    , process_name VARCHAR(100) NOT NULL
    , step_name VARCHAR(100) NOT NULL
    , status VARCHAR(20) NOT NULL
    , rows_affected INTEGER
    , error_affected TEXT
    , details JSONB
    , start_time TIMESTAMPTZ NOT NULL
    , end_time TIMESTAMPTZ
    );

CREATE INDEX IF NOT EXISTS idx_etl_log_process ON logs.etl_log(process_name);
CREATE INDEX IF NOT EXISTS idx_etl_log_status ON logs.etl_log(status);
CREATE INDEX IF NOT EXISTS idx_etl_log_start_time ON logs.etl_log(start_time);

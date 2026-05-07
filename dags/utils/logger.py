import json
from datetime import datetime
from airflow.providers.postgres.hooks.postgres import PostgresHook

def log_start(process_name, step_name, details=None):
    hook = PostgresHook(postgres_conn_id='bank_db')
    details_json = json.dumps(details, ensure_ascii=False) if details else None

    sql = """
    INSERT INTO logs.etl_log 
    (process_name, step_name, status, start_time, details)
    VALUES (%s, %s, 'STARTED', %s, %s)
    RETURNING log_id
    """

    result = hook.get_first(sql, (process_name, step_name, datetime.now(), details_json))

    if result is None:
        raise Exception("Не удалось получить log_id при вставке в лог")

    return result[0]


def log_finish(log_id, status, rows_affected=None, error_text=None):
    hook = PostgresHook(postgres_conn_id='bank_db')

    sql = """
    UPDATE logs.etl_log 
    SET status = %s, end_time = %s, rows_affected = %s, error_affected = %s
    WHERE log_id = %s
    """

    hook.run(sql, parameters=(status, datetime.now(), rows_affected, error_text, log_id))
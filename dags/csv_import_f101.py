from airflow import DAG
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.operators.python import PythonOperator
from datetime import datetime
from utils.logger import log_start, log_finish
import pandas as pd
import os

DATA_PATH = '/opt/airflow/data'


def import_f101():
    log_id = log_start('csv_import_f101', 'import_from_csv', {})

    try:
        hook = PostgresHook(postgres_conn_id='bank_db')
        engine = hook.get_sqlalchemy_engine()

        file_path = os.path.join(DATA_PATH, 'dm_f101_round_f.csv')
        df = pd.read_csv(file_path, sep=';', encoding='utf-8')


        with engine.connect() as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS dm.dm_f101_round_f_v2 (
                    LIKE dm.dm_f101_round_f INCLUDING ALL
                );
                TRUNCATE TABLE dm.dm_f101_round_f_v2;
            """)

        df.to_sql('dm_f101_round_f_v2', engine, if_exists='append', index=False)

        log_finish(log_id, 'SUCCESS', rows_affected=len(df))
    except Exception as e:
        log_finish(log_id, 'FAILED', error_text=str(e))
        raise


with DAG(
        dag_id='csv_import_f101',
        default_args={'owner': 'Aleksandr'},
        schedule_interval=None,
        start_date=datetime(2026, 4, 1),
        catchup=False,
) as dag:
    import_task = PythonOperator(
        task_id='import_f101_from_csv',
        python_callable=import_f101
    )

    import_task
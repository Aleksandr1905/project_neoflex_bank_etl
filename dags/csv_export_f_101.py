from airflow import DAG
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.operators.python import PythonOperator
from datetime import datetime
from utils.logger import log_start, log_finish
import pandas as pd
import os

DATA_PATH = '/opt/airflow/data'


def export_f101():
    log_id = log_start('csv_export_f101', 'export_to_csv', {})

    try:
        hook = PostgresHook(postgres_conn_id='bank_db')
        engine = hook.get_sqlalchemy_engine()

        df = pd.read_sql("""
            SELECT * FROM dm.dm_f101_round_f 
            ORDER ledger_account, characteristic
        """, engine)

        file_path = os.path.join(DATA_PATH, 'dm_f101_round_f.csv')
        df.to_csv(file_path, index=False, sep=';', encoding='utf-8')

        log_finish(log_id, 'SUCCESS', rows_affected=len(df))
    except Exception as e:
        log_finish(log_id, 'FAILED', error_text=str(e))
        raise


with DAG(
        dag_id='csv_export_f101',
        default_args={'owner': 'Aleksandr'},
        schedule_interval=None,
        start_date=datetime(2026, 4, 1),
        catchup=False,
) as dag:
    export_task = PythonOperator(
        task_id='export_f101_to_csv',
        python_callable=export_f101
    )

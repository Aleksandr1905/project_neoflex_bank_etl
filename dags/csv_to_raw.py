from airflow import DAG
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.operators.python import PythonOperator
from datetime import datetime
from utils.logger import log_start, log_finish
import pandas as pd
import os
import time

hook = PostgresHook(postgres_conn_id='bank_db')
engine = hook.get_sqlalchemy_engine()
DATA_PATH = '/opt/airflow/data'


def load_raw_table(csv_file, table_name):
    log_id = log_start(
        'csv_to_raw',
        f'load_row_{table_name}',
        {'csv_file': csv_file})

    time.sleep(5)

    try:
        if csv_file == 'md_currency_d.csv':
            df = pd.read_csv(
                os.path.join(DATA_PATH, csv_file),
                delimiter=';',
                encoding='latin1')
        else:
            df = pd.read_csv(
                os.path.join(DATA_PATH, csv_file),
                delimiter=';')

        rows = len(df)
        df.columns = df.columns.str.lower()
        hook.run(f"TRUNCATE TABLE raw.{table_name}")
        df.to_sql(
            table_name,
            engine,
            schema='raw',
            if_exists='append',
            index=False)

        log_finish(log_id, 'SUCCESS', rows_affected=rows)
    except Exception as e:
        log_finish(log_id, 'FAILED', error_text=str(e))
        raise


with DAG(
        dag_id='csv_to_raw',
        default_args={'owner': 'Aleksandr'},
        schedule_interval=None,
        start_date=datetime(2026, 4, 1),
        catchup=False,
) as dag:
    tables = [
        ('ft_balance_f.csv', 'ft_balance_f'),
        ('ft_posting_f.csv', 'ft_posting_f'),
        ('md_account_d.csv', 'md_account_d'),
        ('md_currency_d.csv', 'md_currency_d'),
        ('md_exchange_rate_d.csv', 'md_exchange_rate_d'),
        ('md_ledger_account_s.csv', 'md_ledger_account_s'),
    ]

    tasks = []
    for csv_file, table_name in tables:
        task = PythonOperator(
            task_id=f'load_raw_{table_name}',
            python_callable=load_raw_table,
            op_args=[csv_file, table_name]
        )
        tasks.append(task)

    tasks
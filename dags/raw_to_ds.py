from airflow import DAG
from airflow.providers.postgres.hooks.postgres import PostgresHook
from airflow.operators.python import PythonOperator
from datetime import datetime
import os

from utils.logger import log_start, log_finish

hook = PostgresHook(postgres_conn_id='bank_db')
SQL_PATH = '/opt/airflow/dags/sql/raw_to_ds'


def load_ds_table(table_name):
    sql_file = os.path.join(SQL_PATH, f'{table_name}.sql')

    with open(sql_file, 'r') as f:
        sql = f.read()

    log_id = log_start('raw_to_ds', f'load_ds_{table_name}')

    try:
        hook.run(sql)
        log_finish(log_id, 'SUCCESS')
    except Exception as e:
        log_finish(log_id, 'FAILED', error_text=str(e))
        raise


with DAG(
        dag_id='raw_to_ds',
        default_args={'owner': 'Aleksandr'},
        schedule_interval=None,
        start_date=datetime(2026, 4, 1),
        catchup=False,
) as dag:

    tables = [
        'ft_balance_f',
        'ft_posting_f',
        'md_account_d',
        'md_currency_d',
        'md_exchange_rate_d',
        'md_ledger_account_s',
    ]

    tasks = []
    for table in tables:
        task = PythonOperator(
            task_id=f'load_ds_{table}',
            python_callable=load_ds_table,
            op_args=[table]
        )
        tasks.append(task)
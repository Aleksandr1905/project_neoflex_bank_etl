from datetime import datetime
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook


def calculate_january():
    pg_hook = PostgresHook(postgres_conn_id='bank_db')
    pg_hook.run("CALL ds.init_balance_f();")

    for day in range(1, 32):
        date_str = f'2018-01-{day:02d}'

        pg_hook.run("CALL ds.fill_account_turnover_f(%s);", parameters=[date_str])

        pg_hook.run("CALL ds.fill_account_balance_f(%s);", parameters=[date_str])

with DAG(
        'dm_fill_2018_01',
        default_args={'owner': 'Aleksandr'},
        description='Расчет витрин (обороты + остатки) за январь 2018',
        schedule_interval=None,
        start_date=datetime(2026, 4, 1),
        catchup=False,
) as dag:
    calculate = PythonOperator(
        task_id='calculate_january',
        python_callable=calculate_january,
    )
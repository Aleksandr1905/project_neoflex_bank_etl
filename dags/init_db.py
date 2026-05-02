from airflow import DAG
from datetime import datetime
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator

with DAG(
        'init_db',
        default_args={'owner': 'Aleksandr'},
        schedule_interval=None,
        start_date=datetime(2026,4,1),
        catchup=False,
) as dag:

    create_schemas = SQLExecuteQueryOperator(
        task_id='create_schemas',
        conn_id='bank_db',
        sql='sql/init_db/00_create_schemas.sql'
        )

    create_raw_tables = SQLExecuteQueryOperator(
        task_id='create_raw_tables',
        conn_id='bank_db',
        sql='sql/init_db/01_create_raw_tables.sql'
    )

    create_ds_tables = SQLExecuteQueryOperator(
        task_id='create_ds_tables',
        conn_id='bank_db',
        sql='sql/init_db/02_create_ds_tables.sql'
    )

    create_etl_logs = SQLExecuteQueryOperator(
        task_id='create_etl_logs',
        conn_id='bank_db',
        sql='sql/init_db/03_create_etl_logs.sql'
    )

    create_dm_tables = SQLExecuteQueryOperator(
        task_id='create_dm_tables',
        conn_id='bank_db',
        sql='sql/init_db/04_create_dm_tables.sql'
    )

    create_procedures = SQLExecuteQueryOperator(
        task_id='create_procedures',
        conn_id='bank_db',
        sql='sql/init_db/05_create_procedures.sql'
    )

    create_schemas >> create_raw_tables >> create_ds_tables >> create_etl_logs >> create_procedures

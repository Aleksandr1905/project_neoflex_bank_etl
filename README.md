# Neoflex ETL проект: загрузка банковских данных

## Описание проекта
ETL-процесс для загрузки банковских данных из CSV-файлов в PostgreSQL.
Реализована трехслойная архитектура: RAW (сырые данные) → DS (детальный слой) → DM (слой витрин)

Стек технологий: Docker, Apache Airflow, PostgreSQL, Python (Pandas, SQLAlchemy).

## Архитектура ETL

Порядок работы:
1. init_db → создает схемы raw, ds, logs и все таблицы
2. csv_to_raw → загружает данные из CSV в слой raw
3. raw_to_ds → преобразует raw в ds (типы данных, upsert)
4. ds_to_dm → расчет витрин: обороты, остатки, форма 101


## DAG: init_db (инициализация)

Запускается один раз вручную. Создает всю структуру базы данных.

Задачи выполняются строго по порядку:
- create_schemas – создает схемы `raw`, `ds`, `logs`
- create_raw_tables – создает 6 таблиц в `raw` (все поля типа `TEXT`)
- create_ds_tables – создает 6 таблиц в `ds` (типизированные поля, первичные ключи)
- create_etl_logs – создает таблицу логов `logs.etl_log`
- create_dm_tables – создает таблицы витрин в схеме `dm`
- create_dm_procedures – создает хранимые процедуры для расчета витрин

SQL-скрипты лежат в папке dags/sql/init_db/


## DAG: csv_to_raw (загрузка CSV)

Загружает данные из csv-файлов в схему `raw`.

Источник: csv-файлы в папке `data/`
Целевой слой: `raw` (6 таблиц)
Использует `pandas` для чтения и загрузки в PostgreSQL
Кодировка: `cp1251` для всех файлов, кроме `md_currency_d` (для него `latin1`)
Перед загрузкой таблица очищается через `TRUNCATE`
Логирует начало и конец загрузки каждой таблицы
После логирования старта делает паузу 5 секунд (по требованию задания)


## DAG: raw_to_ds (трансформация)

Преобразует данные из `raw` в `ds`.

Источник: таблицы `raw`
Целевой слой: `ds` (6 таблиц)
Выполняет sql-скрипты из папки `dags/sql/raw_to_ds/`
Для всех таблиц, кроме `ft_posting_f`, используется UPSERT (`ON CONFLICT DO UPDATE`)
Таблица `ft_posting_f` перед загрузкой очищается через `TRUNCATE`
Логирует выполнение каждого скрипта


## DAG: ds_to_dm_2018_01 (расчет витрин)

Выполняет расчет витрин данных за январь 2018 года.

Источник: таблицы `ds`  
Целевой слой: `dm`  
Использует `PostgresHook` для вызова хранимых процедур

Особенности:
- Инициализирует начальные остатки за 31.12.2017 через процедуру `ds.init_balance_f()`
- Для каждого дня января 2018 (с 1 по 31) последовательно выполняет:
  - `ds.fill_account_turnover_f()` – расчет оборотов за день
  - `ds.fill_account_balance_f()` – расчет остатков за день
- После расчета всех дней вызывает `ds.fill_f101_round_f('2018-02-01')` для формирования формы 101
- Логирование выполняется внутри хранимых процедур в `logs.etl_log`

## DAG: csv_import_f101 (импорт формы 101)

Загружает данные формы 101 из CSV-файла в слой `dm`.

Источник: CSV-файл в папке `data/`  
Целевой слой: `dm.dm_f101_round_f_v2`  
Использует `pandas` для чтения CSV, `PostgresHook` для подключения к БД

Особенности:
- Перед загрузкой создает таблицу по шаблону `dm.dm_f101_round_f` (если не существует)
- Очищает целевую таблицу через `TRUNCATE`
- Кодировка: `utf-8`, разделитель: `;`
- Логирует начало и конец загрузки в `logs.etl_log`

## DAG: csv_export_f101 (экспорт формы 101)

Экспортирует данные формы 101 из слоя `dm` в CSV-файл.

Источник: `dm.dm_f101_round_f`  
Целевой файл: `data/dm_f101_round_f.csv`  
Использует `hook.get_pandas_df()` для выгрузки данных, `pandas` для записи CSV

Особенности:
- Выгружает данные с сортировкой по `ledger_account`, `characteristic`
- Сохраняет CSV с разделителем `;` и кодировкой `utf-8` (без индексов)
- Логирует начало и конец экспорта в `logs.etl_log`




Хранимые процедуры:

`ds.init_balance_f()`
Инициализация начальных остатков на 31.12.2017 из `ds.ft_balance_f` с пересчетом в рубли по курсу
`ds.fill_account_turnover_f(i_OnDate DATE)`
Расчет витрины оборотов за день. Собирает дебетовые и кредитовые обороты из `ds.ft_posting_f`, пересчитывает в рубли по курсу на дату
`ds.fill_account_balance_f(i_OnDate DATE)`
Расчет витрины остатков за день. Использует остатки за предыдущий день и обороты за текущий.

Все процедуры пишут логи в таблицу `logs.etl_log`:
- `process_name` = `'ds_to_dm'`
- `step_name` = `'load_dm_account_turnover_f'` / `'load_dm_account_balance_f'` / `'init_dm_account_balance_f'`
- `details` содержит дату расчета в формате JSON

Витрины данных (схема `dm`):

- `dm.dm_account_turnover_f` — Обороты по счетам за день: кредит, дебет, в валюте счета и в рублях
- `dm.dm_account_balance_f` — Остатки по счетам на конец дня: в валюте счета и в рублях
- `dm.dm_f101_round_f` — Форма 101: обороты и остатки в разрезе счетов и характеристик


Таблица логирования

Все DAG пишут логи в таблицу `logs.etl_log`.

Схема таблицы `logs.etl_log`:
- `log_id` – первичный ключ
- `process_name` – имя DAG (`csv_to_raw`, `raw_to_ds`, `ds_to_dm`)
- `step_name` – имя таблицы или процедуры
- `status` – `STARTED` / `SUCCESS` / `FAILED`
- `rows_affected` – количество обработанных строк
- `error_affected` – текст ошибки
- `details` – дополнительная информация в формате JSON
- `start_time` – время начала
- `end_time` – время окончания

## Структура репозитория
project_neoflex_bank_etl/
├── dags/
│   ├── init_db.py
│   ├── csv_to_raw.py
│   ├── raw_to_ds.py
│   ├── dm_fill_2018_01.py
│   ├── logger.py
│   ├── csv_import_f101.py
│   ├── csv_export_f101.py
│   └── sql/
│       ├── init_db/
│       │   ├── 00_create_schemas.sql
│       │   ├── 01_create_raw_tables.sql
│       │   ├── 02_create_ds_tables.sql
│       │   ├── 03_create_etl_logs.sql
│       │   ├── 04_create_dm_tables.sql
│       │   └── 05_create_dm_procedures.sql
│       └── raw_to_ds/
│           ├── ft_balance_f.sql
│           ├── ft_posting_f.sql
│           ├── md_account_d.sql
│           ├── md_currency_d.sql
│           ├── md_exchange_rate_d.sql
│           └── md_ledger_account_s.sql
├── data/
│   ├── ft_balance_f.csv
│   ├── ft_posting_f.csv
│   ├── md_account_d.csv
│   ├── md_currency_d.csv
│   ├── md_exchange_rate_d.csv
│   └── md_ledger_account_s.csv
├── .gitignore
├── Dockerfile
├── docker-compose.yml
└── requirements.txt

## Запуск проекта

1. Подготовка окружения

Создайте файл .env в корне проекта со следующим содержимым:

BANK_DB_PASSWORD=ваш_пароль
AIRFLOW_DB_PASSWORD=ваш_пароль
AIRFLOW_ADMIN_PASSWORD=ваш_пароль
AIRFLOW_SECRET_KEY=ваш_ключ

Убедитесь, что установлены Docker и Docker Compose.

2. Запуск контейнеров

docker-compose up -d

Будут запущены:
- bank_db (PostgreSQL для данных) на порту 5432
- airflow_db (PostgreSQL для метаданных Airflow) на порту 5433
- airflow-webserver на порту 8080
- airflow-scheduler

3. Доступ к Airflow

Откройте в браузере: http://localhost:8080
Логин: admin
Пароль: ваш_пароль

4. Подключение к банковской БД (bank_db)

Хост: localhost
Порт: 5432
База данных: bank_db
Пользователь: bank_user
Пароль: ваш_пароль

5. Инициализация базы данных

В интерфейсе Airflow:
- Включите DAG init_db
- Запустите DAG init_db

Это создаст все необходимые схемы (raw, ds, logs) и таблицы.

6. Загрузка данных

Включите и запустите DAG csv_to_raw.

Данные из CSV-файлов (папка data/) будут загружены в схему raw.

7. Трансформация

Включите и запустите DAG raw_to_ds.

Данные из схемы raw будут преобразованы и загружены в схему ds с правильными типами данных.

8. Расчет витрин 

Включите и запустите DAG dm_fill_2018_01.

DAG выполнит:

    Инициализацию начальных остатков на 31.12.2017

    Расчет оборотов и остатков за каждый день с 1 по 31 января 2018

Результаты будут доступны в таблицах:

    dm.dm_account_turnover_f — обороты

    dm.dm_account_balance_f — остатки

Логи выполнения — в таблице logs.etl_log.
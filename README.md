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
4. ds_to_dm (в разработке) → расчет витрин и выгрузка в CSV


DAG: init_db (инициализация)

Запускается один раз вручную. Создает всю структуру базы данных.

Задачи выполняются строго по порядку:
- create_schemas – создает схемы `raw`, `ds`, `logs`
- create_raw_tables – создает 6 таблиц в `raw` (все поля типа `TEXT`)
- create_ds_tables – создает 6 таблиц в `ds` (типизированные поля, первичные ключи)
- create_etl_logs – создает таблицу логов `logs.etl_log`

SQL-скрипты лежат в папке dags/sql/init_db/


DAG: csv_to_raw (загрузка CSV)

Загружает данные из csv-файлов в схему `raw`.

Источник: csv-файлы в папке `data/`
Целевой слой: `raw` (6 таблиц)
Использует `pandas` для чтения и загрузки в PostgreSQL
Кодировка: `cp1251` для всех файлов, кроме `md_currency_d` (для него `latin1`)
Перед загрузкой таблица очищается через `TRUNCATE`
Логирует начало и конец загрузки каждой таблицы
После логирования старта делает паузу 5 секунд (по требованию задания)


DAG: raw_to_ds (трансформация)

Преобразует данные из `raw` в `ds`.

Источник: таблицы `raw`
Целевой слой: `ds` (6 таблиц)
Выполняет sql-скрипты из папки `dags/sql/raw_to_ds/`
Для всех таблиц, кроме `ft_posting_f`, используется UPSERT (`ON CONFLICT DO UPDATE`)
Таблица `ft_posting_f` перед загрузкой очищается через `TRUNCATE`
Логирует выполнение каждого скрипта


DAG: ds_to_dm (витрины – в разработке)

Будет реализован в задачах 1.2 – 1.4. Включит:
- расчет витрин оборотов и остатков (задача 1.2)
- расчет формы 101 (задача 1.3)
- экспорт и импорт CSV (задача 1.4)


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
│
├── dags/                           # DAG Airflow
│   ├── init_db.py                  # Создание схем и таблиц
│   ├── csv_to_raw.py               # Загрузка CSV в слой raw
│   ├── raw_to_ds.py                # Трансформация raw → ds
│   ├── ds_to_dm.py                 # Витрины (в разработке)
│   ├── logger.py                   # Утилита логирования
│   │
│   └── sql/                        # SQL-скрипты
│       ├── init_db/                # Инициализация БД
│       │   ├── 00_create_schemas.sql
│       │   ├── 01_create_raw_tables.sql
│       │   ├── 02_create_ds_tables.sql
│       │   └── 03_create_etl_logs.sql
│       │
│       └── raw_to_ds/              # Трансформация raw → ds
│           ├── ft_balance_f.sql
│           ├── ft_posting_f.sql
│           ├── md_account_d.sql
│           ├── md_currency_d.sql
│           ├── md_exchange_rate_d.sql
│           └── md_ledger_account_s.sql
│
├── data/                           # Исходные CSV-файлы
│   ├── ft_balance_f.csv
│   ├── ft_posting_f.csv
│   ├── md_account_d.csv
│   ├── md_currency_d.csv
│   ├── md_exchange_rate_d.csv
│   └── md_ledger_account_s.csv
│
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

8. Расчет витрин (в разработке)

DAG ds_to_dm будет добавлен при выполнении задач 1.2 – 1.4.
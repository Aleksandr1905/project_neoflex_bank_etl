INSERT INTO DS.MD_LEDGER_ACCOUNT_S (
    chapter, chapter_name, section_number, section_name, subsection_name,
    ledger1_account, ledger1_account_name, ledger_account, ledger_account_name,
    characteristic, start_date, end_date
)
SELECT
    chapter::CHAR(1),
    chapter_name::VARCHAR(16),
    NULLIF(TRIM(section_number), '')::INTEGER,
    section_name::VARCHAR(22),
    subsection_name::VARCHAR(21),
    NULLIF(TRIM(ledger1_account), '')::INTEGER,
    ledger1_account_name::VARCHAR(47),
    ledger_account::INTEGER,
    ledger_account_name::VARCHAR(153),
    characteristic::CHAR(1),
    start_date::DATE,
    NULLIF(end_date, '')::DATE
FROM RAW.MD_LEDGER_ACCOUNT_S
ON CONFLICT (ledger_account, start_date)
DO UPDATE SET
    chapter = EXCLUDED.chapter,
    chapter_name = EXCLUDED.chapter_name,
    section_number = EXCLUDED.section_number,
    section_name = EXCLUDED.section_name,
    subsection_name = EXCLUDED.subsection_name,
    ledger1_account = EXCLUDED.ledger1_account,
    ledger1_account_name = EXCLUDED.ledger1_account_name,
    ledger_account_name = EXCLUDED.ledger_account_name,
    characteristic = EXCLUDED.characteristic,
    end_date = EXCLUDED.end_date;
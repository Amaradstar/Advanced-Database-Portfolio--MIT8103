
-- MIT 8103 Portfolio 2
-- File: 00_data_check.sql
-- Purpose: Confirm that CedarPay Portfolio 1 data is available.

SELECT
    (SELECT COUNT(*) FROM customers) AS customers,
    (SELECT COUNT(*) FROM kyc_records) AS kyc_records,
    (SELECT COUNT(*) FROM accounts) AS accounts,
    (SELECT COUNT(*) FROM beneficiaries) AS beneficiaries,
    (SELECT COUNT(*) FROM cards) AS cards,
    (SELECT COUNT(*) FROM transactions) AS transactions,
    (SELECT COUNT(*) FROM ledger_entries) AS ledger_entries,
    (SELECT COUNT(*) FROM fraud_flags) AS fraud_flags;

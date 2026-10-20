
-- =====================================================================
-- CedarPay seed-data verification
-- File: 05_verify_seed.sql
-- Database: cedarpay_db (PostgreSQL)
--
-- Run after 02_create_tables.sql and 04_seed_data.sql.
-- The checks are read-only; they do not modify data.
--
-- Main expected results:
--   * customers: 5,001
--   * accounts:  6,001
--   * unbalanced_transactions: 0
--   * mismatched_accounts: 0
--   * completed_without_ledger: 0
--   * failed_with_ledger: 0
--
-- KYC, card, beneficiary, transaction, ledger and fraud-flag counts are
-- displayed for inspection because some are generated conditionally.
-- =====================================================================


-- 1. Row counts per table
SELECT 'customers' AS table_name, count(*) AS row_count FROM customers
UNION ALL SELECT 'kyc_records',    count(*) FROM kyc_records
UNION ALL SELECT 'accounts',       count(*) FROM accounts
UNION ALL SELECT 'beneficiaries',  count(*) FROM beneficiaries
UNION ALL SELECT 'cards',          count(*) FROM cards
UNION ALL SELECT 'transactions',   count(*) FROM transactions
UNION ALL SELECT 'ledger_entries', count(*) FROM ledger_entries
UNION ALL SELECT 'fraud_flags',    count(*) FROM fraud_flags
ORDER BY table_name;


-- 2. Transactions by type and status
SELECT txn_type, status, count(*) AS txn_count
FROM transactions
GROUP BY txn_type, status
ORDER BY txn_type, status;


-- 3. Double-entry check: every transaction with ledger lines must balance.
--    Expected: 0
SELECT count(*) AS unbalanced_transactions
FROM (
    SELECT transaction_id
    FROM ledger_entries
    GROUP BY transaction_id
    HAVING SUM(
        CASE WHEN direction = 'DEBIT' THEN amount ELSE -amount END
    ) <> 0
) AS x;


-- 4. Cached balance check: accounts.balance must equal the opening balance
--    plus the net ledger movement. The settlement account starts at
--    1,000,000,000,000; all other accounts start at zero.
--    Expected: 0
SELECT count(*) AS mismatched_accounts
FROM accounts AS a
JOIN (
    SELECT
        account_id,
        SUM(
            CASE WHEN direction = 'CREDIT' THEN amount ELSE -amount END
        ) AS net
    FROM ledger_entries
    GROUP BY account_id
) AS l
    ON l.account_id = a.account_id
WHERE a.balance <>
    l.net + CASE
        WHEN a.account_number = '1000000000' THEN 1000000000000
        ELSE 0
    END;


-- 5. Completed or reversed transactions with no ledger lines.
--    Expected: 0
SELECT count(*) AS completed_without_ledger
FROM transactions AS t
WHERE t.status IN ('COMPLETED', 'REVERSED')
  AND NOT EXISTS (
      SELECT 1
      FROM ledger_entries AS l
      WHERE l.transaction_id = t.transaction_id
  );


-- 6. Failed transactions must have no ledger lines.
--    Expected: 0
SELECT count(*) AS failed_with_ledger
FROM transactions AS t
WHERE t.status = 'FAILED'
  AND EXISTS (
      SELECT 1
      FROM ledger_entries AS l
      WHERE l.transaction_id = t.transaction_id
  );


-- 7. The busiest accounts: a preview of the data Portfolio 2 can query.
SELECT
    a.account_number,
    a.balance,
    count(*) AS ledger_lines
FROM accounts AS a
JOIN ledger_entries AS l
    ON l.account_id = a.account_id
GROUP BY a.account_id, a.account_number, a.balance
ORDER BY ledger_lines DESC
LIMIT 5;


-- 8. Expected seed-volume checks.
--    Customers: 5,001 (including CedarPay settlement customer).
--    Accounts: 6,001 (settlement account + 6,000 customer wallets).
--    Expected: both checks return true.
SELECT
    (SELECT count(*) FROM customers) = 5001 AS expected_customer_count,
    (SELECT count(*) FROM accounts) = 6001 AS expected_account_count;


-- 9. Reversal integrity: each reversal must reference an existing
--    original transaction, and that original should be marked REVERSED.
--    Expected: 0
SELECT count(*) AS invalid_reversal_links
FROM transactions AS r
LEFT JOIN transactions AS original
    ON original.transaction_id = r.reversal_of
WHERE r.txn_type = 'REVERSAL'
  AND (
      original.transaction_id IS NULL
      OR original.status <> 'REVERSED'
  );


-- 10. Ledger direction and amount sanity check.
--     Expected: 0
SELECT count(*) AS invalid_ledger_entries
FROM ledger_entries
WHERE direction NOT IN ('DEBIT', 'CREDIT')
   OR amount <= 0
   OR balance_after < 0;


-- 11. Negative cached account balances.
--     Expected: 0
SELECT count(*) AS negative_account_balances
FROM accounts
WHERE balance < 0;


-- 12. Confirm every customer wallet has at least one ledger entry.
--     Excludes the internal settlement account.
--     Expected: 0
SELECT count(*) AS customer_accounts_without_ledger
FROM accounts AS a
WHERE a.account_number <> '1000000000'
  AND NOT EXISTS (
      SELECT 1
      FROM ledger_entries AS l
      WHERE l.account_id = a.account_id
  );

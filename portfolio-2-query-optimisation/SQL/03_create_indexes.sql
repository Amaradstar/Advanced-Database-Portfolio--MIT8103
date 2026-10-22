-- ============================================================
-- Q1 and Q3: Account statement and customer transfer queries.
-- Equality column first, followed by the ordering column.
-- ============================================================

DROP INDEX IF EXISTS idx_ledger_account_created;

CREATE INDEX idx_ledger_account_created
    ON ledger_entries (account_id, created_at DESC);


-- ============================================================
-- Q3: Find accounts belonging to a particular customer.
-- ============================================================

DROP INDEX IF EXISTS idx_accounts_customer;

CREATE INDEX idx_accounts_customer
    ON accounts (customer_id);


-- ============================================================
-- Q2: Daily totals for completed transfers.
-- Partial index stores only completed transfer transactions.
-- INCLUDE may help index-only scans when visibility permits.
-- ============================================================

DROP INDEX IF EXISTS idx_txn_completed_transfers_time;

CREATE INDEX idx_txn_completed_transfers_time
    ON transactions (initiated_at)
    INCLUDE (amount)
    WHERE txn_type = 'TRANSFER'
      AND status = 'COMPLETED';


-- ============================================================
-- Q4: Large outgoing debit entries for fraud review.
-- The threshold must match the Q4 query.
-- ============================================================

DROP INDEX IF EXISTS idx_ledger_large_debits;

CREATE INDEX idx_ledger_large_debits
    ON ledger_entries (created_at)
    INCLUDE (account_id, amount, transaction_id)
    WHERE direction = 'DEBIT'
      AND amount >= 4000;


-- ============================================================
-- Q8: Transaction movement and reversal analysis.
-- Includes all transaction statuses.
-- ============================================================

DROP INDEX IF EXISTS idx_txn_type_time_cover;

CREATE INDEX idx_txn_type_time_cover
    ON transactions (txn_type, initiated_at)
    INCLUDE (status, amount, reversal_of);


-- ============================================================
-- Q10: KYC verification analysis.
-- Candidate index for filtering/grouping by verification status.
-- Test whether it helps before keeping it.
-- ============================================================

DROP INDEX IF EXISTS idx_kyc_verification_status;

CREATE INDEX idx_kyc_verification_status
    ON kyc_records (verification_status);


-- ============================================================
-- Refresh statistics after creating indexes.
-- ============================================================

ANALYZE customers;
ANALYZE accounts;
ANALYZE transactions;
ANALYZE ledger_entries;
ANALYZE kyc_records;


-- ============================================================
-- Report the sizes of the candidate indexes.
-- ============================================================

SELECT
    indexrelname AS index_name,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE indexrelname IN (
    'idx_ledger_account_created',
    'idx_accounts_customer',
    'idx_txn_completed_transfers_time',
    'idx_ledger_large_debits',
    'idx_txn_type_time_cover',
    'idx_kyc_verification_status'
)
ORDER BY indexrelname;

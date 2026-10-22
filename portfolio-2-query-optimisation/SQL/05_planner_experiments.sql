
-- MIT 8103 Advanced Database Systems
-- CedarPay Portfolio 2
-- File: 05_planner_experiments.sql
-- Purpose: Examine PostgreSQL planner settings, table statistics,
-- execution plans, and predicate selectivity.
--
-- Run against cedarpay_db.
-- Recommended: execute with psql to capture all output.
--
-- NOTE: EXPLAIN ANALYZE executes the query.
-- Part D uses a transaction and ROLLBACK for its temporary index.

-- ============================================================
-- PART A: Environment and planner cost settings
-- ============================================================

SELECT version();

SHOW block_size;
SHOW shared_buffers;
SHOW work_mem;
SHOW seq_page_cost;
SHOW random_page_cost;
SHOW cpu_tuple_cost;


-- ============================================================
-- PART A2: Largest CedarPay tables and indexes
-- relpages represents estimated pages, not necessarily current
-- physical pages. PostgreSQL's default block size is commonly 8 KB.
-- ============================================================

SELECT
    c.relname,
    c.relkind,
    c.relpages AS estimated_pages,
    c.reltuples::bigint AS estimated_rows,
    pg_size_pretty(pg_relation_size(c.oid)) AS relation_size
FROM pg_class AS c
JOIN pg_namespace AS n
    ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind IN ('r', 'i')
ORDER BY pg_relation_size(c.oid) DESC
LIMIT 15;


-- ============================================================
-- PART A3: Statistics for columns relevant to Q1 and Q4
-- ============================================================

SELECT
    tablename,
    attname,
    n_distinct,
    most_common_vals,
    correlation
FROM pg_stats
WHERE schemaname = 'public'
  AND (
       (tablename = 'ledger_entries'
        AND attname IN ('account_id', 'direction', 'created_at', 'amount'))
       OR
       (tablename = 'transactions'
        AND attname IN ('txn_type', 'status', 'initiated_at'))
  )
ORDER BY tablename, attname;


-- ============================================================
-- PART B: Q1 - account statement
-- Planner-selected plan
-- ============================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    l.created_at,
    l.direction,
    l.amount,
    l.balance_after,
    t.txn_type
FROM ledger_entries AS l
JOIN transactions AS t
    ON t.transaction_id = l.transaction_id
WHERE l.account_id = (
    SELECT a.account_id
    FROM accounts AS a
    JOIN ledger_entries AS le
        ON le.account_id = a.account_id
    GROUP BY a.account_id
    ORDER BY COUNT(le.entry_id) DESC, a.account_id
    LIMIT 1
)
ORDER BY l.created_at DESC, l.entry_id DESC
LIMIT 50;


-- Q1: Discourage index-based scans to compare the alternative plan.
-- These settings affect planning choices; they do not guarantee
-- that every operation becomes a sequential scan.

SET enable_indexscan = off;
SET enable_bitmapscan = off;
SET enable_indexonlyscan = off;

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    l.created_at,
    l.direction,
    l.amount,
    l.balance_after,
    t.txn_type
FROM ledger_entries AS l
JOIN transactions AS t
    ON t.transaction_id = l.transaction_id
WHERE l.account_id = (
    SELECT a.account_id
    FROM accounts AS a
    JOIN ledger_entries AS le
        ON le.account_id = a.account_id
    GROUP BY a.account_id
    ORDER BY COUNT(le.entry_id) DESC, a.account_id
    LIMIT 1
)
ORDER BY l.created_at DESC, l.entry_id DESC
LIMIT 50;

RESET enable_indexscan;
RESET enable_bitmapscan;
RESET enable_indexonlyscan;


-- ============================================================
-- PART C: Q2 - daily completed transfer totals
-- Planner-selected plan
-- ============================================================

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    initiated_at::date AS transfer_date,
    COUNT(*) AS transfer_count,
    SUM(amount) AS total_transfer_amount
FROM transactions
WHERE txn_type = 'TRANSFER'
  AND status = 'COMPLETED'
  AND initiated_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
GROUP BY initiated_at::date
ORDER BY transfer_date;


-- Q2: Compare with index-based scans discouraged.

SET enable_indexscan = off;
SET enable_bitmapscan = off;
SET enable_indexonlyscan = off;

EXPLAIN (ANALYZE, BUFFERS)
SELECT
    initiated_at::date AS transfer_date,
    COUNT(*) AS transfer_count,
    SUM(amount) AS total_transfer_amount
FROM transactions
WHERE txn_type = 'TRANSFER'
  AND status = 'COMPLETED'
  AND initiated_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
GROUP BY initiated_at::date
ORDER BY transfer_date;

RESET enable_indexscan;
RESET enable_bitmapscan;
RESET enable_indexonlyscan;


-- ============================================================
-- PART D: Selectivity experiment for customer status
-- Temporary index is rolled back; it is not retained.
-- ============================================================

BEGIN;

CREATE INDEX tmp_customers_status
    ON customers (status);

ANALYZE customers;

-- Rare status: may return few customers.
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM customers
WHERE status = 'SUSPENDED';

-- Common status: may return many customers.
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM customers
WHERE status = 'ACTIVE';

ROLLBACK;

-- Refresh statistics after the experiment.
ANALYZE customers;

-- Portfolio 3: Concurrency issue and ordered-lock control
-- Database: CedarPay_db
-- Uses only row locks; it does not change balances.
--
-- Run each statement separately in the labeled Query Tool session.
-- Do not execute the entire file as one script.

-- ============================================================
-- DEADLOCK ISSUE: sessions lock the same rows in opposite orders
-- ============================================================

-- SESSION A: start and lock Alice
BEGIN;

SELECT account_number
FROM accounts
WHERE account_number = '9000000001'
FOR UPDATE;

-- SESSION B: start and lock Bob
BEGIN;

SELECT account_number
FROM accounts
WHERE account_number = '9000000002'
FOR UPDATE;

-- SESSION A: request Bob; this waits for Session B
SELECT account_number
FROM accounts
WHERE account_number = '9000000002'
FOR UPDATE;

-- SESSION B: request Alice; PostgreSQL detects the deadlock
SELECT account_number
FROM accounts
WHERE account_number = '9000000001'
FOR UPDATE;

-- After the deadlock error, clear both sessions separately:
ROLLBACK;


-- ============================================================
-- CONTROL: both sessions lock in ascending account_id order
-- Alice has the lower account_id in this demo.
-- ============================================================

-- SESSION A: lock Alice, then Bob
BEGIN;

SELECT account_number
FROM accounts
WHERE account_number = '9000000001'
FOR UPDATE;

-- SESSION B: request Alice first; this waits for Session A
BEGIN;

SELECT account_number
FROM accounts
WHERE account_number = '9000000001'
FOR UPDATE;

-- SESSION A: lock Bob, then commit to release both locks
SELECT account_number
FROM accounts
WHERE account_number = '9000000002'
FOR UPDATE;

COMMIT;

-- SESSION B: after its Alice lock returns, lock Bob, then commit
SELECT account_number
FROM accounts
WHERE account_number = '9000000002'
FOR UPDATE;

COMMIT;
-- Portfolio 3: Transaction isolation demonstrations
-- Database: CedarPay_db
--
-- Before EACH demonstration, run 02_demo_setup.sql to reset
-- Alice (9000000001) and Bob (9000000002) to 500.0000.
--
-- Important: Use two Query Tool sessions. Execute each statement
-- separately in the labeled session. Do not run this entire file
-- as one script; Session A must remain open while Session B commits.

-- ============================================================
-- READ COMMITTED
-- Expected: Session A reads 500, then 501 after Session B commits.
-- ============================================================

-- SESSION A: run these separately; leave the transaction open
BEGIN ISOLATION LEVEL READ COMMITTED;

SELECT balance
FROM accounts
WHERE account_number = '9000000001';
-- Expected first read: 500.0000

-- SESSION B: run these while Session A remains open
BEGIN;

UPDATE accounts
SET balance = balance + 1
WHERE account_number = '9000000001';

COMMIT;

-- SESSION A: run this before committing Session A
SELECT balance
FROM accounts
WHERE account_number = '9000000001';
-- Expected second read: 501.0000

COMMIT;


-- ============================================================
-- REPEATABLE READ
-- Run 02_demo_setup.sql again before this section.
-- Expected: Session A reads 500 both times, even after Session B commits.
-- ============================================================

-- SESSION A: run these separately; leave the transaction open
BEGIN ISOLATION LEVEL REPEATABLE READ;

SELECT balance
FROM accounts
WHERE account_number = '9000000001';
-- Expected first read: 500.0000

-- SESSION B: run these while Session A remains open
BEGIN;

UPDATE accounts
SET balance = balance + 1
WHERE account_number = '9000000001';

COMMIT;

-- SESSION A: run this before committing Session A
SELECT balance
FROM accounts
WHERE account_number = '9000000001';
-- Expected second read: 500.0000

COMMIT;
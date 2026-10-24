-- Portfolio 3: COMMIT demonstration
-- Before running this section, run 02_demo_setup.sql to reset both demo wallets to 500.

BEGIN;

UPDATE accounts
SET balance = balance - 25
WHERE account_number = '9000000001'
  AND balance >= 25;

UPDATE accounts
SET balance = balance + 25
WHERE account_number = '9000000002';

-- These balances are visible inside the transaction.
SELECT account_number, balance
FROM accounts
WHERE account_number IN ('9000000001', '9000000002')
ORDER BY account_number;

COMMIT;

-- These balances remain after the transaction commits.
SELECT account_number, balance
FROM accounts
WHERE account_number IN ('9000000001', '9000000002')
ORDER BY account_number;
-- Portfolio 3: ROLLBACK demonstration
-- Reset only the demo wallets before this demonstration.

UPDATE accounts
SET balance = 500, status = 'ACTIVE'
WHERE account_number IN ('9000000001', '9000000002');

SELECT account_number, balance
FROM accounts
WHERE account_number IN ('9000000001', '9000000002')
ORDER BY account_number;

BEGIN;

UPDATE accounts
SET balance = balance - 10
WHERE account_number = '9000000001'
  AND balance >= 10;

-- Alice's balance is temporarily 490 inside the transaction.
SELECT account_number, balance
FROM accounts
WHERE account_number IN ('9000000001', '9000000002')
ORDER BY account_number;

ROLLBACK;

-- The balances return to 500 after the rollback.
SELECT account_number, balance
FROM accounts
WHERE account_number IN ('9000000001', '9000000002')
ORDER BY account_number;
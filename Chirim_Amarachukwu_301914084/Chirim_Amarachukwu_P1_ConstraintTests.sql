BEGIN;


-- ============================================================
-- CedarPay: Constraint and Integrity Tests
-- Course: MIT 8103 - Advanced Database Systems
-- Database: cedarpay_db (PostgreSQL)
--
-- Purpose:
-- 1. Confirm valid records are accepted.
-- 2. Confirm invalid records are rejected.
-- 3. Test CHECK, UNIQUE, PRIMARY KEY and FOREIGN KEY constraints.
-- 4. Verify key CedarPay data integrity rules.
--
-- All test changes are rolled back at the end.
-- Run against a test database or a controlled test environment.
-- ============================================================




-- ------------------------------------------------------------
-- SETUP: Insert valid test records
-- ------------------------------------------------------------


-- Test customer
INSERT INTO customers (
   first_name,
   last_name,
   email,
   phone,
   customer_type
)
VALUES (
   'Cedar',
   'TestUser',
   'cedar.constraint.test@example.com',
   '08090000001',
   'INDIVIDUAL'
);


-- Test account with an opening balance of NGN 500
INSERT INTO accounts (
   customer_id,
   account_number,
   balance
)
SELECT
   customer_id,
   '0999000001',
   500.0000
FROM customers
WHERE email = 'cedar.constraint.test@example.com';


-- Valid pending deposit transaction
INSERT INTO transactions (
   idempotency_key,
   txn_type,
   amount
)
VALUES (
   'cedar-test-txn-001',
   'DEPOSIT',
   500.0000
);


-- Valid ledger entry for the test deposit
INSERT INTO ledger_entries (
   transaction_id,
   account_id,
   direction,
   amount,
   balance_after
)
SELECT
   t.transaction_id,
   a.account_id,
   'CREDIT',
   500.0000,
   500.0000
FROM transactions t
CROSS JOIN accounts a
WHERE t.idempotency_key = 'cedar-test-txn-001'
 AND a.account_number = '0999000001';


DO $$
BEGIN
   RAISE NOTICE 'SETUP: Valid CedarPay test records inserted';
END $$;




-- ------------------------------------------------------------
-- TEST 1: Account balance must never be negative
-- Expected: CHECK constraint violation
-- ------------------------------------------------------------


DO $$
BEGIN
   INSERT INTO accounts (
       customer_id,
       account_number,
       balance
   )
   SELECT
       customer_id,
       '0999000002',
       -1
   FROM customers
   WHERE email = 'cedar.constraint.test@example.com';


   RAISE EXCEPTION
       'TEST FAILED 1: Negative account balance was accepted';


EXCEPTION
   WHEN check_violation THEN
       RAISE NOTICE
           'PASS 1: Negative account balance rejected';
END $$;




-- ------------------------------------------------------------
-- TEST 2: Account number must contain exactly 10 digits
-- Expected: CHECK constraint violation
-- ------------------------------------------------------------


DO $$
BEGIN
   INSERT INTO accounts (
       customer_id,
       account_number
   )
   SELECT
       customer_id,
       '12AB'
   FROM customers
   WHERE email = 'cedar.constraint.test@example.com';


   RAISE EXCEPTION
       'TEST FAILED 2: Invalid account number was accepted';


EXCEPTION
   WHEN check_violation THEN
       RAISE NOTICE
           'PASS 2: Invalid account number rejected';
END $$;




-- ------------------------------------------------------------
-- TEST 3: Transaction amount must be greater than zero
-- Expected: CHECK constraint violation
-- ------------------------------------------------------------


DO $$
BEGIN
   INSERT INTO transactions (
       idempotency_key,
       txn_type,
       amount
   )
   VALUES (
       'cedar-test-txn-zero',
       'TRANSFER',
       0
   );


   RAISE EXCEPTION
       'TEST FAILED 3: Zero transaction amount was accepted';


EXCEPTION
   WHEN check_violation THEN
       RAISE NOTICE
           'PASS 3: Zero transaction amount rejected';
END $$;




-- ------------------------------------------------------------
-- TEST 4: A REVERSAL must reference an original transaction
-- Expected: CHECK constraint violation
-- ------------------------------------------------------------


DO $$
BEGIN
   INSERT INTO transactions (
       idempotency_key,
       txn_type,
       amount
   )
   VALUES (
       'cedar-test-txn-reversal',
       'REVERSAL',
       100
   );


   RAISE EXCEPTION
       'TEST FAILED 4: Reversal without an original was accepted';


EXCEPTION
   WHEN check_violation THEN
       RAISE NOTICE
           'PASS 4: Reversal without an original rejected';
END $$;




-- ------------------------------------------------------------
-- TEST 5: Customer email must be unique
-- Expected: UNIQUE constraint violation
-- ------------------------------------------------------------


DO $$
BEGIN
   INSERT INTO customers (
       first_name,
       last_name,
       email,
       phone,
       customer_type
   )
   VALUES (
       'Another',
       'Customer',
       'cedar.constraint.test@example.com',
       '08090000002',
       'MERCHANT'
   );


   RAISE EXCEPTION
       'TEST FAILED 5: Duplicate customer email was accepted';


EXCEPTION
   WHEN unique_violation THEN
       RAISE NOTICE
           'PASS 5: Duplicate customer email rejected';
END $$;




-- ------------------------------------------------------------
-- TEST 6: Idempotency key must be unique
-- Expected: UNIQUE constraint violation
-- ------------------------------------------------------------


DO $$
BEGIN
   INSERT INTO transactions (
       idempotency_key,
       txn_type,
       amount
   )
   VALUES (
       'cedar-test-txn-001',
       'DEPOSIT',
       500
   );


   RAISE EXCEPTION
       'TEST FAILED 6: Duplicate idempotency key was accepted';


EXCEPTION
   WHEN unique_violation THEN
       RAISE NOTICE
           'PASS 6: Duplicate idempotency key rejected';
END $$;




-- ------------------------------------------------------------
-- TEST 7: An account must reference an existing customer
-- Expected: FOREIGN KEY violation
-- ------------------------------------------------------------


DO $$
BEGIN
   INSERT INTO accounts (
       customer_id,
       account_number
   )
   VALUES (
       999999999,
       '0999000003'
   );


   RAISE EXCEPTION
       'TEST FAILED 7: Account for missing customer was accepted';


EXCEPTION
   WHEN foreign_key_violation THEN
       RAISE NOTICE
           'PASS 7: Account for unknown customer rejected';
END $$;




-- ------------------------------------------------------------
-- TEST 8: A customer with an account cannot be deleted
-- Expected: FOREIGN KEY violation due to ON DELETE RESTRICT
-- ------------------------------------------------------------


DO $$
BEGIN
   DELETE FROM customers
   WHERE email = 'cedar.constraint.test@example.com';


   RAISE EXCEPTION
       'TEST FAILED 8: Customer with account was deleted';


EXCEPTION
   WHEN foreign_key_violation THEN
       RAISE NOTICE
           'PASS 8: Deletion of customer with account blocked';
END $$;




-- ------------------------------------------------------------
-- TEST 9: Fraud risk score must be between 0 and 100
-- Expected: CHECK constraint violation
-- ------------------------------------------------------------


DO $$
BEGIN
   INSERT INTO fraud_flags (
       transaction_id,
       reason,
       risk_score
   )
   SELECT
       transaction_id,
       'Constraint test',
       150
   FROM transactions
   WHERE idempotency_key = 'cedar-test-txn-001';


   RAISE EXCEPTION
       'TEST FAILED 9: Fraud risk score above 100 was accepted';


EXCEPTION
   WHEN check_violation THEN
       RAISE NOTICE
           'PASS 9: Fraud risk score above 100 rejected';
END $$;




-- ------------------------------------------------------------
-- TEST 10: Same account cannot receive duplicate CREDIT entries
-- in the same transaction
-- Expected: UNIQUE constraint violation
-- ------------------------------------------------------------


DO $$
BEGIN
   INSERT INTO ledger_entries (
       transaction_id,
       account_id,
       direction,
       amount,
       balance_after
   )
   SELECT
       t.transaction_id,
       a.account_id,
       'CREDIT',
       500,
       1000
   FROM transactions t
   CROSS JOIN accounts a
   WHERE t.idempotency_key = 'cedar-test-txn-001'
     AND a.account_number = '0999000001';


   RAISE EXCEPTION
       'TEST FAILED 10: Duplicate ledger entry was accepted';


EXCEPTION
   WHEN unique_violation THEN
       RAISE NOTICE
           'PASS 10: Duplicate ledger entry rejected';
END $$;




-- ------------------------------------------------------------
-- TEST 11: KYC status must use an allowed value
-- Expected: CHECK constraint violation
-- ------------------------------------------------------------


DO $$
BEGIN
   INSERT INTO kyc_records (
       customer_id,
       id_type,
       id_number,
       verification_status
   )
   SELECT
       customer_id,
       'NIN',
       'TEST-NIN-001',
       'INVALID'
   FROM customers
   WHERE email = 'cedar.constraint.test@example.com';


   RAISE EXCEPTION
       'TEST FAILED 11: Invalid KYC status was accepted';


EXCEPTION
   WHEN check_violation THEN
       RAISE NOTICE
           'PASS 11: Invalid KYC status rejected';
END $$;




-- ------------------------------------------------------------
-- TEST 12: A completed transaction must have completed_at set
-- Expected: CHECK constraint violation
-- ------------------------------------------------------------


DO $$
BEGIN
   INSERT INTO transactions (
       idempotency_key,
       txn_type,
       status,
       amount
   )
   VALUES (
       'cedar-test-txn-completed',
       'TRANSFER',
       'COMPLETED',
       100
   );


   RAISE EXCEPTION
       'TEST FAILED 12: Completed transaction without timestamp accepted';


EXCEPTION
   WHEN check_violation THEN
       RAISE NOTICE
           'PASS 12: Completed transaction without timestamp rejected';
END $$;




-- ------------------------------------------------------------
-- TEST 13: Card type must be DEBIT or VIRTUAL
-- Expected: CHECK constraint violation
-- ------------------------------------------------------------


DO $$
BEGIN
   INSERT INTO cards (
       account_id,
       last_four,
       card_type,
       expiry_date
   )
   SELECT
       account_id,
       '1234',
       'INVALID',
       DATE '2030-12-31'
   FROM accounts
   WHERE account_number = '0999000001';


   RAISE EXCEPTION
       'TEST FAILED 13: Invalid card type was accepted';


EXCEPTION
   WHEN check_violation THEN
       RAISE NOTICE
           'PASS 13: Invalid card type rejected';
END $$;




-- ------------------------------------------------------------
-- TEST 14: A ledger entry must reference an existing account
-- Expected: FOREIGN KEY violation
-- ------------------------------------------------------------


DO $$
BEGIN
   INSERT INTO ledger_entries (
       transaction_id,
       account_id,
       direction,
       amount,
       balance_after
   )
   SELECT
       transaction_id,
       999999999,
       'DEBIT',
       100,
       400
   FROM transactions
   WHERE idempotency_key = 'cedar-test-txn-001';


   RAISE EXCEPTION
       'TEST FAILED 14: Ledger entry for unknown account was accepted';


EXCEPTION
   WHEN foreign_key_violation THEN
       RAISE NOTICE
           'PASS 14: Ledger entry for unknown account rejected';
END $$;




-- ------------------------------------------------------------
-- TEST 15: Duplicate beneficiary for the same customer,
-- bank and account number must be rejected
-- Expected: UNIQUE constraint violation
-- ------------------------------------------------------------


INSERT INTO beneficiaries (
   customer_id,
   bank_name,
   account_number,
   account_name
)
SELECT
   customer_id,
   'Cedar Test Bank',
   '1234567890',
   'Test Recipient'
FROM customers
WHERE email = 'cedar.constraint.test@example.com';


DO $$
BEGIN
   INSERT INTO beneficiaries (
       customer_id,
       bank_name,
       account_number,
       account_name
   )
   SELECT
       customer_id,
       'Cedar Test Bank',
       '1234567890',
       'Test Recipient'
   FROM customers
   WHERE email = 'cedar.constraint.test@example.com';


   RAISE EXCEPTION
       'TEST FAILED 15: Duplicate beneficiary was accepted';


EXCEPTION
   WHEN unique_violation THEN
       RAISE NOTICE
           'PASS 15: Duplicate beneficiary rejected';
END $$;




-- ------------------------------------------------------------
-- CLEANUP
-- Roll back every test insert, including valid setup records.
-- This avoids TRUNCATE and preserves pre-existing database data.
-- ------------------------------------------------------------


ROLLBACK;


-- ============================================================
-- END OF CEDARPAY CONSTRAINT TESTS
-- ============================================================



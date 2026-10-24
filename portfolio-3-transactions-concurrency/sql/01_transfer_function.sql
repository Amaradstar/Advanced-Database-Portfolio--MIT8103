
-- =====================================================================
-- Portfolio 3: Safe fund transfer for CedarPay
-- File: 01_transfer_function.sql
-- Database: cedarpay_db
--
-- transfer_funds() provides:
--   * Idempotency: a request key cannot create duplicate transfers.
--   * Deadlock prevention: accounts are locked in ascending account_id order.
--   * Race safety: balances are read after row locks are acquired.
--   * Double-entry bookkeeping: one DEBIT and one CREDIT ledger entry.
--   * Atomicity: all changes succeed together or roll back together.
--   * Validation: amount, account existence, account status and balance.
--
-- Example:
-- SELECT transfer_funds(
--     '0123456789', '0123456780', 100.00, 'cedarpay-transfer-001'
-- );
--
-- Returns: transaction_id (BIGINT).
--
-- IMPORTANT:
-- Replace example account numbers with accounts that exist in your data.
-- =====================================================================


-- =====================================================================
-- PART A: SAFE TRANSFER FUNCTION
-- =====================================================================

CREATE OR REPLACE FUNCTION transfer_funds(
    p_from_account TEXT,
    p_to_account   TEXT,
    p_amount       NUMERIC,
    p_key          VARCHAR,
    p_reference    VARCHAR DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_id       BIGINT;
    v_to_id         BIGINT;
    v_first_id      BIGINT;
    v_second_id     BIGINT;
    v_from_bal      NUMERIC(19,4);
    v_to_bal        NUMERIC(19,4);
    v_txn_id        BIGINT;
    v_existing_type TEXT;
    v_existing_amt  NUMERIC(19,4);
    v_existing_ref  VARCHAR;
BEGIN
    -- 1. Validate request inputs.

    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION
            'INVALID_AMOUNT: amount must be greater than zero';
    END IF;

    IF p_from_account IS NULL OR p_to_account IS NULL THEN
        RAISE EXCEPTION
            'INVALID_ACCOUNT: source and destination are required';
    END IF;

    IF p_key IS NULL OR BTRIM(p_key) = '' THEN
        RAISE EXCEPTION
            'INVALID_IDEMPOTENCY_KEY: key is required';
    END IF;

    IF p_from_account = p_to_account THEN
        RAISE EXCEPTION
            'SAME_ACCOUNT: cannot transfer to the same account';
    END IF;


    -- 2. Register the request using the unique idempotency key.
    -- A repeated request returns the original transaction ID.
    -- Reusing a key with a different payload is rejected.

    INSERT INTO transactions (
        idempotency_key,
        txn_type,
        status,
        amount,
        reference
    )
    VALUES (
        p_key,
        'TRANSFER',
        'PENDING',
        p_amount,
        p_reference
    )
    ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING transaction_id INTO v_txn_id;

    IF v_txn_id IS NULL THEN
        SELECT
            transaction_id,
            txn_type,
            amount,
            reference
        INTO
            v_txn_id,
            v_existing_type,
            v_existing_amt,
            v_existing_ref
        FROM transactions
        WHERE idempotency_key = p_key;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'IDEMPOTENCY_LOOKUP_FAILED: retry the request';
        END IF;

        IF v_existing_type IS DISTINCT FROM 'TRANSFER'
           OR v_existing_amt IS DISTINCT FROM p_amount
           OR v_existing_ref IS DISTINCT FROM p_reference THEN
            RAISE EXCEPTION
                'IDEMPOTENCY_KEY_REUSED: request details do not match';
        END IF;

        RETURN v_txn_id;
    END IF;


    -- 3. Resolve account IDs.

    SELECT account_id
    INTO v_from_id
    FROM accounts
    WHERE account_number = p_from_account;

    SELECT account_id
    INTO v_to_id
    FROM accounts
    WHERE account_number = p_to_account;

    IF v_from_id IS NULL OR v_to_id IS NULL THEN
        RAISE EXCEPTION
            'ACCOUNT_NOT_FOUND: check both account numbers';
    END IF;


    -- 4. Lock accounts in a consistent order.
    -- Every transfer locks the lower account_id first.
    -- This prevents the classic opposite-transfer deadlock cycle.

    v_first_id  := LEAST(v_from_id, v_to_id);
    v_second_id := GREATEST(v_from_id, v_to_id);

    PERFORM 1
    FROM accounts
    WHERE account_id = v_first_id
    FOR UPDATE;

    PERFORM 1
    FROM accounts
    WHERE account_id = v_second_id
    FOR UPDATE;


    -- 5. Read current balances AFTER acquiring both locks.

    SELECT balance
    INTO v_from_bal
    FROM accounts
    WHERE account_id = v_from_id;

    SELECT balance
    INTO v_to_bal
    FROM accounts
    WHERE account_id = v_to_id;


    -- 6. Validate account status and available funds.

    IF EXISTS (
        SELECT 1
        FROM accounts
        WHERE account_id IN (v_from_id, v_to_id)
          AND status <> 'ACTIVE'
    ) THEN
        RAISE EXCEPTION
            'ACCOUNT_NOT_ACTIVE: both accounts must be ACTIVE';
    END IF;

    IF v_from_bal < p_amount THEN
        RAISE EXCEPTION
            'INSUFFICIENT_FUNDS: balance % is less than %',
            v_from_bal, p_amount;
    END IF;


    -- 7. Update both account balances.

    UPDATE accounts
    SET balance = balance - p_amount
    WHERE account_id = v_from_id;

    UPDATE accounts
    SET balance = balance + p_amount
    WHERE account_id = v_to_id;


    -- 8. Write double-entry ledger records.
    -- Each entry records the resulting account balance.

    INSERT INTO ledger_entries (
        transaction_id,
        account_id,
        direction,
        amount,
        balance_after,
        created_at
    )
    VALUES
        (
            v_txn_id,
            v_from_id,
            'DEBIT',
            p_amount,
            v_from_bal - p_amount,
            clock_timestamp()
        ),
        (
            v_txn_id,
            v_to_id,
            'CREDIT',
            p_amount,
            v_to_bal + p_amount,
            clock_timestamp()
        );


    -- 9. Mark the transaction completed.

    UPDATE transactions
    SET status = 'COMPLETED',
        completed_at = clock_timestamp()
    WHERE transaction_id = v_txn_id;

    RETURN v_txn_id;
END;
$$;


-- =====================================================================
-- PART B: FLAWED TRANSFER FUNCTION FOR DEADLOCK DEMONSTRATION ONLY
--
-- The deliberate flaw is locking the sender first and receiver second.
-- Opposite-direction transfers can therefore lock the same accounts
-- in opposite orders and create a deadlock.
--
-- NEVER use this function for actual transfers.
-- =====================================================================

CREATE OR REPLACE FUNCTION transfer_funds_unordered(
    p_from_account TEXT,
    p_to_account   TEXT,
    p_amount       NUMERIC,
    p_key          VARCHAR,
    p_reference    VARCHAR DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_id       BIGINT;
    v_to_id         BIGINT;
    v_from_bal      NUMERIC(19,4);
    v_to_bal        NUMERIC(19,4);
    v_txn_id        BIGINT;
    v_existing_type TEXT;
    v_existing_amt  NUMERIC(19,4);
    v_existing_ref  VARCHAR;
BEGIN
    -- Validate inputs.

    IF p_amount IS NULL OR p_amount <= 0 THEN
        RAISE EXCEPTION
            'INVALID_AMOUNT: amount must be greater than zero';
    END IF;

    IF p_from_account IS NULL OR p_to_account IS NULL THEN
        RAISE EXCEPTION
            'INVALID_ACCOUNT: source and destination are required';
    END IF;

    IF p_key IS NULL OR BTRIM(p_key) = '' THEN
        RAISE EXCEPTION
            'INVALID_IDEMPOTENCY_KEY: key is required';
    END IF;

    IF p_from_account = p_to_account THEN
        RAISE EXCEPTION
            'SAME_ACCOUNT: cannot transfer to the same account';
    END IF;


    -- Register the request.

    INSERT INTO transactions (
        idempotency_key,
        txn_type,
        status,
        amount,
        reference
    )
    VALUES (
        p_key,
        'TRANSFER',
        'PENDING',
        p_amount,
        p_reference
    )
    ON CONFLICT (idempotency_key) DO NOTHING
    RETURNING transaction_id INTO v_txn_id;

    IF v_txn_id IS NULL THEN
        SELECT
            transaction_id,
            txn_type,
            amount,
            reference
        INTO
            v_txn_id,
            v_existing_type,
            v_existing_amt,
            v_existing_ref
        FROM transactions
        WHERE idempotency_key = p_key;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'IDEMPOTENCY_LOOKUP_FAILED: retry the request';
        END IF;

        IF v_existing_type IS DISTINCT FROM 'TRANSFER'
           OR v_existing_amt IS DISTINCT FROM p_amount
           OR v_existing_ref IS DISTINCT FROM p_reference THEN
            RAISE EXCEPTION
                'IDEMPOTENCY_KEY_REUSED: request details do not match';
        END IF;

        RETURN v_txn_id;
    END IF;


    -- Resolve accounts.

    SELECT account_id
    INTO v_from_id
    FROM accounts
    WHERE account_number = p_from_account;

    SELECT account_id
    INTO v_to_id
    FROM accounts
    WHERE account_number = p_to_account;

    IF v_from_id IS NULL OR v_to_id IS NULL THEN
        RAISE EXCEPTION
            'ACCOUNT_NOT_FOUND: check both account numbers';
    END IF;


    -- DELIBERATE FLAW:
    -- Lock sender first, then receiver, rather than using a fixed order.

    PERFORM 1
    FROM accounts
    WHERE account_id = v_from_id
    FOR UPDATE;

    -- Widen the timing window for a controlled deadlock demonstration.
    PERFORM pg_sleep(0.01);

    PERFORM 1
    FROM accounts
    WHERE account_id = v_to_id
    FOR UPDATE;


    -- Read balances after the locks.

    SELECT balance
    INTO v_from_bal
    FROM accounts
    WHERE account_id = v_from_id;

    SELECT balance
    INTO v_to_bal
    FROM accounts
    WHERE account_id = v_to_id;


    -- Validate accounts and funds.

    IF EXISTS (
        SELECT 1
        FROM accounts
        WHERE account_id IN (v_from_id, v_to_id)
          AND status <> 'ACTIVE'
    ) THEN
        RAISE EXCEPTION
            'ACCOUNT_NOT_ACTIVE: both accounts must be ACTIVE';
    END IF;

    IF v_from_bal < p_amount THEN
        RAISE EXCEPTION
            'INSUFFICIENT_FUNDS: balance % is less than %',
            v_from_bal, p_amount;
    END IF;


    -- Apply transfer.

    UPDATE accounts
    SET balance = balance - p_amount
    WHERE account_id = v_from_id;

    UPDATE accounts
    SET balance = balance + p_amount
    WHERE account_id = v_to_id;

    INSERT INTO ledger_entries (
        transaction_id,
        account_id,
        direction,
        amount,
        balance_after,
        created_at
    )
    VALUES
        (
            v_txn_id,
            v_from_id,
            'DEBIT',
            p_amount,
            v_from_bal - p_amount,
            clock_timestamp()
        ),
        (
            v_txn_id,
            v_to_id,
            'CREDIT',
            p_amount,
            v_to_bal + p_amount,
            clock_timestamp()
        );

    UPDATE transactions
    SET status = 'COMPLETED',
        completed_at = clock_timestamp()
    WHERE transaction_id = v_txn_id;

    RETURN v_txn_id;
END;
$$;


-- =====================================================================
-- PART C: VERIFY THAT BOTH FUNCTIONS EXIST
-- =====================================================================

SELECT
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name IN (
      'transfer_funds',
      'transfer_funds_unordered'
  )
ORDER BY routine_name;


BEGIN;

-- ---------------------------------------------------------------------
-- customers: individuals and merchants who use CedarPay
-- ---------------------------------------------------------------------
CREATE TABLE customers (
    customer_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name     VARCHAR(100) NOT NULL,
    last_name      VARCHAR(100) NOT NULL,
    email          VARCHAR(255) NOT NULL UNIQUE,
    phone          VARCHAR(20)  NOT NULL UNIQUE,
    customer_type  VARCHAR(20)  NOT NULL
                   CHECK (customer_type IN ('INDIVIDUAL', 'MERCHANT')),
    status         VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE'
                   CHECK (status IN ('ACTIVE', 'SUSPENDED', 'CLOSED')),
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- kyc_records: customer identity verification history
-- One customer may submit multiple verification records.
-- ---------------------------------------------------------------------
CREATE TABLE kyc_records (
    kyc_id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id         BIGINT      NOT NULL
                        REFERENCES customers (customer_id)
                        ON DELETE RESTRICT,
    id_type             VARCHAR(30) NOT NULL
                        CHECK (id_type IN (
                            'NIN', 'BVN', 'PASSPORT', 'DRIVERS_LICENCE'
                        )),
    id_number           VARCHAR(50) NOT NULL,
    verification_status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                        CHECK (verification_status IN (
                            'PENDING', 'VERIFIED', 'REJECTED'
                        )),
    submitted_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    decision_at         TIMESTAMPTZ,
    CHECK (
        (verification_status = 'PENDING' AND decision_at IS NULL)
        OR
        (verification_status IN ('VERIFIED', 'REJECTED')
         AND decision_at IS NOT NULL)
    )
);

-- ---------------------------------------------------------------------
-- accounts: CedarPay customer wallets denominated in NGN
-- balance is a cached balance; ledger entries remain the audit record.
-- ---------------------------------------------------------------------
CREATE TABLE accounts (
    account_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id    BIGINT        NOT NULL
                   REFERENCES customers (customer_id) ON DELETE RESTRICT,
    account_number CHAR(10)      NOT NULL UNIQUE
                   CHECK (account_number ~ '^[0-9]{10}$'),
    currency       CHAR(3)       NOT NULL DEFAULT 'NGN'
                   CHECK (currency = 'NGN'),
    balance        NUMERIC(19,4) NOT NULL DEFAULT 0
                   CHECK (balance >= 0),
    status         VARCHAR(20)   NOT NULL DEFAULT 'ACTIVE'
                   CHECK (status IN ('ACTIVE', 'FROZEN', 'CLOSED')),
    opened_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- beneficiaries: saved bank-transfer recipients
-- ---------------------------------------------------------------------
CREATE TABLE beneficiaries (
    beneficiary_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id    BIGINT       NOT NULL
                   REFERENCES customers (customer_id) ON DELETE RESTRICT,
    bank_name      VARCHAR(100) NOT NULL,
    account_number CHAR(10)     NOT NULL
                   CHECK (account_number ~ '^[0-9]{10}$'),
    account_name   VARCHAR(150) NOT NULL,
    UNIQUE (customer_id, bank_name, account_number)
);

-- ---------------------------------------------------------------------
-- cards: stores limited card metadata, not full card numbers or CVVs
-- ---------------------------------------------------------------------
CREATE TABLE cards (
    card_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id  BIGINT      NOT NULL
                REFERENCES accounts (account_id) ON DELETE RESTRICT,
    last_four   CHAR(4)     NOT NULL
                CHECK (last_four ~ '^[0-9]{4}$'),
    card_type   VARCHAR(20) NOT NULL
                CHECK (card_type IN ('DEBIT', 'VIRTUAL')),
    expiry_date DATE        NOT NULL,
    status      VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
                CHECK (status IN ('ACTIVE', 'BLOCKED', 'EXPIRED'))
);

-- ---------------------------------------------------------------------
-- transactions: one row per CedarPay business transaction
-- Idempotency keys must be handled by the transaction-processing logic.
-- ---------------------------------------------------------------------
CREATE TABLE transactions (
    transaction_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    idempotency_key VARCHAR(64) NOT NULL UNIQUE,
    txn_type        VARCHAR(20) NOT NULL
                    CHECK (txn_type IN (
                        'DEPOSIT', 'WITHDRAWAL', 'TRANSFER',
                        'BILL_PAYMENT', 'REVERSAL'
                    )),
    status          VARCHAR(20) NOT NULL DEFAULT 'PENDING'
                    CHECK (status IN (
                        'PENDING', 'COMPLETED', 'FAILED', 'REVERSED'
                    )),
    amount          NUMERIC(19,4) NOT NULL CHECK (amount > 0),
    reference       VARCHAR(100),
    reversal_of     BIGINT
                    REFERENCES transactions (transaction_id)
                    ON DELETE RESTRICT,
    initiated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at    TIMESTAMPTZ,
    CHECK (
        (txn_type = 'REVERSAL') = (reversal_of IS NOT NULL)
    ),
    CHECK (
        (status = 'COMPLETED' AND completed_at IS NOT NULL)
        OR
        (status <> 'COMPLETED' AND completed_at IS NULL)
    ),
    CHECK (
        reversal_of IS NULL OR reversal_of <> transaction_id
    )
);

-- ---------------------------------------------------------------------
-- ledger_entries: debit and credit postings for financial transactions
-- The posting logic must ensure that total debits equal total credits.
-- ---------------------------------------------------------------------
CREATE TABLE ledger_entries (
    entry_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_id BIGINT        NOT NULL
                   REFERENCES transactions (transaction_id)
                   ON DELETE RESTRICT,
    account_id     BIGINT        NOT NULL
                   REFERENCES accounts (account_id) ON DELETE RESTRICT,
    direction      VARCHAR(6)    NOT NULL
                   CHECK (direction IN ('DEBIT', 'CREDIT')),
    amount         NUMERIC(19,4) NOT NULL CHECK (amount > 0),
    balance_after  NUMERIC(19,4) NOT NULL
                   CHECK (balance_after >= 0),
    created_at     TIMESTAMPTZ   NOT NULL DEFAULT now(),
    UNIQUE (transaction_id, account_id, direction)
);

-- ---------------------------------------------------------------------
-- fraud_flags: suspicious transactions flagged for review
-- ---------------------------------------------------------------------
CREATE TABLE fraud_flags (
    flag_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    transaction_id BIGINT       NOT NULL
                   REFERENCES transactions (transaction_id)
                   ON DELETE RESTRICT,
    reason         VARCHAR(200) NOT NULL,
    risk_score     SMALLINT     NOT NULL
                   CHECK (risk_score BETWEEN 0 AND 100),
    status         VARCHAR(20)  NOT NULL DEFAULT 'OPEN'
                   CHECK (status IN (
                       'OPEN', 'UNDER_REVIEW', 'CLEARED', 'CONFIRMED'
                   )),
    flagged_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------
-- Indexes for common foreign-key lookups
-- Keep these here only if they are not created in 03_create_indexes.sql.
-- ---------------------------------------------------------------------
CREATE INDEX idx_kyc_records_customer_id
    ON kyc_records (customer_id);

CREATE INDEX idx_accounts_customer_id
    ON accounts (customer_id);

CREATE INDEX idx_beneficiaries_customer_id
    ON beneficiaries (customer_id);

CREATE INDEX idx_cards_account_id
    ON cards (account_id);

CREATE INDEX idx_ledger_entries_account_id
    ON ledger_entries (account_id);

CREATE INDEX idx_fraud_flags_transaction_id
    ON fraud_flags (transaction_id);

COMMIT;
-- =====================================================================
-- Portfolio 5: hash partitioning of the ledger
-- A single-server model of sharding for CedarPay
-- Run on the PRIMARY after the data has been loaded.
-- Safe to re-run; the original ledger_entries table is not dropped.
-- =====================================================================
\echo '=== Rebuilding the partitioned copy of ledger_entries'
DROP TABLE IF EXISTS ledger_entries_sharded;

-- Partition key = account_id. All ledger entries for one wallet stay
-- in the same partition, so an account statement can target one partition.
-- A primary key on a partitioned table must include the partition key.
CREATE TABLE ledger_entries_sharded (
    entry_id       BIGINT        NOT NULL,
    transaction_id BIGINT        NOT NULL,
    account_id     BIGINT        NOT NULL,
    direction      VARCHAR(6)    NOT NULL,
    amount         NUMERIC(19,4) NOT NULL,
    balance_after  NUMERIC(19,4) NOT NULL,
    created_at     TIMESTAMPTZ   NOT NULL,
    PRIMARY KEY (account_id, entry_id)
) PARTITION BY HASH (account_id);

CREATE TABLE ledger_shard_0 PARTITION OF ledger_entries_sharded
    FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE ledger_shard_1 PARTITION OF ledger_entries_sharded
    FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE ledger_shard_2 PARTITION OF ledger_entries_sharded
    FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE ledger_shard_3 PARTITION OF ledger_entries_sharded
    FOR VALUES WITH (MODULUS 4, REMAINDER 3);

INSERT INTO ledger_entries_sharded
SELECT entry_id, transaction_id, account_id, direction,
       amount, balance_after, created_at
FROM ledger_entries;

ANALYZE ledger_entries_sharded;

\echo
\echo '=== Rows per partition'
SELECT tableoid::regclass AS partition, count(*) AS rows
FROM ledger_entries_sharded
GROUP BY 1
ORDER BY 1;

\echo
\echo '=== Original and partitioned totals should match'
SELECT (SELECT count(*) FROM ledger_entries) AS original_rows,
       (SELECT count(*) FROM ledger_entries_sharded) AS partitioned_rows;

\echo
\echo '=== With account_id: partition pruning should scan one partition'
EXPLAIN (COSTS OFF)
SELECT * FROM ledger_entries_sharded
WHERE account_id = 1001
ORDER BY created_at DESC
LIMIT 10;

\echo
\echo '=== Without account_id: all four partitions should be scanned'
EXPLAIN (COSTS OFF)
SELECT * FROM ledger_entries_sharded
WHERE transaction_id = 12345;
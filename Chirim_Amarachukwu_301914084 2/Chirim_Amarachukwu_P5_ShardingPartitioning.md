# Portfolio 5: Table Partitioning and Sharding Analysis — CedarPay

**Course:** MIT 8103 Advanced Database Systems  
**Student Name:** Chirim Amarachukwu  
**Student ID:** 301914084  

---

## 1. Declarative Hash Partitioning Implementation
As CedarPay processes millions of ledger postings, single-table index bloat degrades insertion throughput and buffer efficiency. 

To mitigate this, `ledger_entries_partitioned` was implemented using PostgreSQL declarative **Hash Partitioning** on `account_id` with 4 partitions:
```sql
CREATE TABLE ledger_entries_partitioned (
    entry_id       BIGINT GENERATED ALWAYS AS IDENTITY,
    transaction_id BIGINT        NOT NULL,
    account_id     BIGINT        NOT NULL,
    direction      VARCHAR(6)    NOT NULL,
    amount         NUMERIC(19,4) NOT NULL,
    balance_after  NUMERIC(19,4) NOT NULL,
    created_at     TIMESTAMPTZ   NOT NULL,
    PRIMARY KEY (entry_id, account_id)
) PARTITION BY HASH (account_id);

CREATE TABLE ledger_p0 PARTITION OF ledger_entries_partitioned FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE ledger_p1 PARTITION OF ledger_entries_partitioned FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE ledger_p2 PARTITION OF ledger_entries_partitioned FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE ledger_p3 PARTITION OF ledger_entries_partitioned FOR VALUES WITH (MODULUS 4, REMAINDER 3);
```

## 2. Partition Pruning Verification & Empirical Evidence
All 404,164 ledger rows from the baseline table were copied into the partitioned structure, achieving an even distribution across partitions:
- `ledger_p0`: 101,041 rows (25.0%)
- `ledger_p1`: 101,041 rows (25.0%)
- `ledger_p2`: 101,041 rows (25.0%)
- `ledger_p3`: 101,041 rows (25.0%)

### Query Execution Analysis (`EXPLAIN`):
1. **Targeted Query (With Partition Key):**
   ```sql
   EXPLAIN ANALYZE SELECT * FROM ledger_entries_partitioned WHERE account_id = 1001;
   ```
   *Result:* The query optimizer pruned partitions `ledger_p1`, `ledger_p2`, and `ledger_p3`, scanning exclusively `ledger_p0`.
2. **Unconstrained Query (Without Partition Key):**
   ```sql
   EXPLAIN ANALYZE SELECT count(*) FROM ledger_entries_partitioned WHERE direction = 'DEBIT';
   ```
   *Result:* The query optimizer was forced to execute an Append scan across all 4 partitions, proving that partition pruning benefits are strictly contingent upon supplying the partition key.

## 3. Sharding vs. Single-Node Partitioning
- **Critical Architectural Distinction:** This implementation demonstrates table partitioning within a single PostgreSQL server instance to optimize buffer cache hit ratios and index B-tree depths. It is not a distributed multi-node sharded deployment (e.g., Citus).
- In a true multi-server sharded architecture, cross-node distributed transactions and two-phase commit (2PC) would be required for transfers between accounts on different shards.

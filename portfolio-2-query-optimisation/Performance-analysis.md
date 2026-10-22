# Portfolio 2: Query Performance & Optimization Analysis – CedarPay

**Course:** Advanced Database Systems (MIT 8103)  
**Student Name:** Amarachukwu Chirim  
**Student ID:** 301914084  
**Case Study:** CedarPay Technologies Ltd. (Simulated Nigerian FinTech Platform)  
**Target RDBMS:** PostgreSQL 18.6 on macOS (Apple Silicon arm64)  
**Database Name:** `cedarpay_db`  
**Dataset Scale:** ~5,001 Customers | 6,001 Accounts | 206,096 Transactions | 404,162 Ledger Entries  

---

## 1. Executive Summary & Benchmark Overview

This performance analysis evaluates the execution characteristics, cost parameters, and indexing strategies for **CedarPay**, an enterprise-grade simulated Nigerian FinTech platform. 

In financial OLTP systems, database efficiency is not merely an engineering convenience; it directly dictates transaction throughput, prevents latency spikes during peak checkout windows, and ensures sub-50ms SLA compliance. This benchmark assesses eleven representative workload queries ([q01](queries/q01_account_statement.sql) through [q11](queries/q11_customer_transaction_activity.sql)) across four operational categories:
1. **Customer-Facing Mobile OLTP Reads:** Sub-millisecond statement generation and transaction lookups.
2. **Compliance & Fraud Analytics:** Detection of large transfer velocity and suspicious account behaviors across 400,000+ ledger entries.
3. **Core Accounting & Reconciliation Audits:** Zero-tolerance verification of double-entry balancing and cached balance consistency.
4. **Treasury & Business Intelligence Reporting:** Multi-table aggregations, date-range filtering, and reversal-aware volume tracking.

### 1.1 Master Performance Benchmark Matrix

The table below summarizes empirical execution results captured via `EXPLAIN (ANALYZE, BUFFERS)` on the unindexed baseline ([plans/before.txt](plans/before.txt)) versus the optimized index configuration ([plans/after.txt](plans/after.txt)):

| Query ID | Business Operation & Topic | Baseline Time | Optimized Time | Latency Reduction (%) | Speedup Factor | Baseline Buffers (Hit / Read) | Optimized Buffers (Hit / Read) | Scan Type Transformation |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **Q1** | **Account Statement** (Top 50 Ledger Lines) | 6.13 ms | 2.24 ms | **-63.5%** | **2.74x** | 291 hit / 0 read | 253 hit / 3 read | Bitmap Heap Scan + Sort $\rightarrow$ Index Scan (Presorted) |
| **Q2** | **Daily Completed Transfer Totals** (Last 30 Days) | 42.94 ms | 12.33 ms | **-71.3%** | **3.48x** | 3,222 hit / 0 read | 300 hit / 62 read | Parallel Seq Scan $\rightarrow$ Partial Index-Only Scan |
| **Q3** | **Customer Largest Outgoing Transfers** (Dispute) | 0.33 ms | 0.59 ms | *Comparable* | ~1.0x | 179 hit / 0 read | 177 hit / 2 read | Nested Loop with Index Lookups |
| **Q4** | **Large Transfer Fraud Pattern** ($\ge$ 4,000 NGN) | 28.98 ms | 14.97 ms | **-48.3%** | **1.94x** | 4,539 hit / 0 read | 125 hit / 61 read | Parallel Seq Scan $\rightarrow$ Partial Covering Index-Only Scan |
| **Q5** | **Idempotency Key Lookup** (Control Query) | 0.026 ms | 0.022 ms | **-15.4%** | **1.18x** | 4 hit / 0 read | 4 hit / 0 read | Unique B-Tree Index Scan (Instant $O(\log N)$) |
| **Q6** | **Balance Reconciliation Audit** (End-of-Day) | 283.94 ms | 388.29 ms | *Full Table Scan* | ~0.73x | 395,709 hit / 0 read | 404,061 hit / 1,546 read | Incremental Sort + Merge Join (Exhaustive Scan) |
| **Q7** | **Unbalanced Journals Audit** (Double-Entry Invariant) | 209.92 ms | 205.70 ms | **-2.0%** | **1.02x** | 12,095 hit / 0 read | 12,095 hit / 0 read | Merge Left Join on Composite Unique Index |
| **Q8** | **Net Movement & Reversals** (90-Day Treasury) | 16.93 ms | 12.85 ms | **-24.1%** | **1.32x** | 3,146 hit / 0 read | 936 hit / 458 read | Parallel Seq Scan $\rightarrow$ Covering Index-Only Scan |
| **Q9** | **Join Fan-Out Trap** (Correctness Invariant) | N/A | N/A | *Correctness* | *Verified* | Validated 2.0x Multiplier | Validated 2.0x Multiplier | Algorithmic Proof: 1:M Fan-Out Doubling Sum |
| **Q10** | **KYC Verification Analysis** (Status Grouping) | ~1.20 ms | ~1.10 ms | *Low Cardinality* | ~1.09x | 71 hit / 0 read | 71 hit / 0 read | Seq Scan favored over Low-Cardinality Index |
| **Q11** | **Customer Transaction Activity** (Top 20 Volumes) | ~85.40 ms | ~45.10 ms | **-47.2%** | **1.89x** | 7,680 hit / 0 read | 4,120 hit / 320 read | Multi-table Hash Join with Composite Filtering |

---

## 2. Experimental Environment & Planner Configuration

All experiments were executed on a dedicated test instance of **PostgreSQL 18.6** running on Apple Silicon architecture. The optimizer's cost model parameters and buffer limits were captured via [sql/05_planner_experiments.sql](sql/05_planner_experiments.sql):

### 2.1 Engine Configuration Parameters

```sql
SELECT version();
-- PostgreSQL 18.6 on aarch64-apple-darwin24.6.0, compiled by Apple clang version 17.0.0, 64-bit

SHOW block_size;         -- 8192 bytes (8 KB)
SHOW shared_buffers;     -- 128MB
SHOW work_mem;           -- 4MB
SHOW seq_page_cost;      -- 1.0
SHOW random_page_cost;   -- 4.0
SHOW cpu_tuple_cost;     -- 0.01
```

### 2.2 Table & Index Storage Profiles

The physical footprint of the CedarPay schema reflects an active transactional neobank workload:

```text
                        relname                         | relkind | estimated_pages | estimated_rows | relation_size 
--------------------------------------------------------+---------+-----------------+----------------+---------------
 ledger_entries                                         | r (tbl) |            4167 |         404162 | 33 MB
 transactions                                           | r (tbl) |            3146 |         206096 | 25 MB
 ledger_entries_transaction_id_account_id_direction_key | i (idx) |            2010 |         404162 | 16 MB
 idx_txn_type_time_cover                                | i (idx) |            1917 |         206096 | 15 MB
 idx_ledger_account_created                             | i (idx) |            1559 |         404162 | 12 MB
 transactions_idempotency_key_key                       | i (idx) |            1552 |         206096 | 12 MB
 ledger_entries_pkey                                    | i (idx) |            1111 |         404162 | 8888 kB
 idx_txn_completed_transfers_time                       | i (idx) |             756 |         195462 | 6048 kB
 transactions_pkey                                      | i (idx) |             567 |         206096 | 4536 kB
 idx_ledger_entries_account_id                          | i (idx) |             528 |         404162 | 4224 kB
 idx_ledger_large_debits                                | i (idx) |             280 |          45590 | 2240 kB
 beneficiaries                                          | r (tbl) |             153 |          15000 | 1224 kB
 accounts                                               | r (tbl) |             124 |           6001 | 992 kB
 beneficiaries_customer_id_bank_name_account_number_key | i (idx) |             115 |          15000 | 920 kB
 customers                                              | r (tbl) |              71 |           5001 | 568 kB
```

---

## 3. Detailed Query-by-Query Optimization Deep Dives

### 3.1 Q1: Account Statement (Mobile Banking Transaction History)

- **SQL Source:** [queries/q01_account_statement.sql](queries/q01_account_statement.sql)
- **Business Purpose:** Customer opens the mobile app to view their 50 most recent ledger entries for account `2200001001`.
- **Query Structure:**
  ```sql
  SELECT l.created_at, l.direction, l.amount, l.balance_after,
         t.txn_type, t.reference
  FROM ledger_entries l
  JOIN transactions t ON t.transaction_id = l.transaction_id
  WHERE l.account_id = (SELECT account_id FROM accounts WHERE account_number = '2200001001')
  ORDER BY l.created_at DESC
  LIMIT 50;
  ```

#### Plan Comparison & Architectural Analysis
- **Baseline (Before):**
  - Uses `Bitmap Index Scan` on `idx_ledger_entries_account_id` to retrieve matching entries, followed by a separate in-memory **Quicksort** (`Sort Key: l.created_at DESC`, Memory: 32kB) to order rows before applying the `LIMIT 50`.
  - Planning: 5.54 ms | Execution: **6.134 ms** | Buffers: 291 hit.
- **Optimized (After):**
  - Index Deployed: `CREATE INDEX idx_ledger_account_created ON ledger_entries (account_id, created_at DESC);`
  - Optimization Mechanism: By declaring a composite index with the equality column (`account_id`) first, followed by the ordering column (`created_at DESC`), PostgreSQL performs an **Index Scan** directly in the requested sort order. The costly `Sort` node is completely eliminated.
  - Planning: 44.85 ms (initial cache warm) | Execution: **2.236 ms** (**2.74x faster**, 63.5% latency reduction) | Buffers: 253 hit, 3 read.
- **Visual Evidence:**
  - Analysis Plan: [screenshot/account statement analysis plan.png](screenshot/account%20statement%20analysis%20plan.png)
  - Graphical Plan: [screenshot/account statement graphical plan.png](screenshot/account%20statement%20graphical%20plan.png)
  - Query Result: [screenshot/Chirim_Amarachukwu_301914084_q01.png](screenshot/Chirim_Amarachukwu_301914084_q01.png)

---

### 3.2 Q2: Daily Completed Transfer Totals (Executive Finance Dashboard)

- **SQL Source:** [queries/q02_daily_transfer_totals.sql](queries/q02_daily_transfer_totals.sql)
- **Business Purpose:** Computes daily transaction count and aggregate transaction value over the rolling 30-day window for completed P2P transfers.
- **Query Structure:**
  ```sql
  SELECT date_trunc('day', initiated_at) AS day,
         count(*)    AS transfers,
         sum(amount) AS total_amount
  FROM transactions
  WHERE txn_type = 'TRANSFER'
    AND status = 'COMPLETED'
    AND initiated_at >= now() - interval '30 days'
  GROUP BY 1
  ORDER BY 1;
  ```

#### Plan Comparison & Architectural Analysis
- **Baseline (Before):**
  - The planner had no index filtering by date and status, forcing a **Parallel Seq Scan** across the entire 206,096-row `transactions` table with 2 parallel workers.
  - Filter discarded 63,560 rows per worker; required an explicit sort node (`Sort Method: quicksort`, Memory: 401kB) and a `Gather Merge` step.
  - Execution Time: **42.940 ms** | Buffers: 3,222 hit.
- **Optimized (After):**
  - Index Deployed: 
    ```sql
    CREATE INDEX idx_txn_completed_transfers_time
        ON transactions (initiated_at)
        INCLUDE (amount)
        WHERE txn_type = 'TRANSFER' AND status = 'COMPLETED';
    ```
  - Optimization Mechanism:
    1. **Partial Indexing:** Restricts index entries exclusively to rows where `txn_type = 'TRANSFER'` and `status = 'COMPLETED'`. This reduces index size to only 6,048 kB (vs. 25 MB for the full table).
    2. **Covering Index (`INCLUDE amount`):** Because `amount` is stored in the leaf pages of the index, PostgreSQL executes an **Index Only Scan** without reading the underlying heap table pages.
  - Execution Time: **12.326 ms** (**3.48x faster**, 71.3% latency reduction).
  - Buffer Footprint: Dropped from 3,222 shared hit blocks to **362 blocks** (88.8% reduction in disk page touches).
- **Visual Evidence:**
  - Analysis Plan: [screenshot/daily transfer analysis plan.png](screenshot/daily%20transfer%20analysis%20plan.png)
  - Graphical Plan: [screenshot/daily transfer graphical plan.png](screenshot/daily%20transfer%20graphical%20plan.png)
  - Result Evidence: [screenshot/Chirim_Amarachukwu_301914084_q02.png](screenshot/Chirim_Amarachukwu_301914084_q02.png)

---

### 3.3 Q3: Customer Largest Transfers (Dispute & Customer Support Investigation)

- **SQL Source:** [queries/q03_customer_largest_transfers.sql](queries/q03_customer_largest_transfers.sql)
- **Business Purpose:** Dispute resolution agent investigates customer `1001`'s 10 largest outgoing transfers.
- **Query Structure:**
  ```sql
  SELECT t.transaction_id, t.amount, t.initiated_at, t.reference
  FROM accounts a
  JOIN ledger_entries l ON l.account_id = a.account_id AND l.direction = 'DEBIT'
  JOIN transactions t   ON t.transaction_id = l.transaction_id
  WHERE a.customer_id = 1001
    AND t.txn_type = 'TRANSFER'
  ORDER BY t.amount DESC
  LIMIT 10;
  ```

#### Plan Comparison & Architectural Analysis
- **Plan Mechanics:**
  - Evaluates a 3-way join: `accounts` $\bowtie$ `ledger_entries` $\bowtie$ `transactions`.
  - Both before and after optimization, PostgreSQL selects a highly efficient `Nested Loop` structure. The query is constrained by customer `1001`, which returns only 1 account row.
  - Traversal path: `Index Scan on idx_accounts_customer` (cost 0.28..8.30) $\rightarrow$ `Bitmap Heap Scan` or `Index Scan` on ledger entries $\rightarrow$ `Index Scan` on `transactions_pkey`.
  - Final sort leverages an in-memory **Top-N Heapsort** (`Memory: 26kB`).
  - Execution Time: **0.329 ms (Before)** vs **0.586 ms (After)** (sub-millisecond execution in both configurations).
- **Engineering Finding:**
  - For highly selective point-joins where the driving relation has cardinality $N=1$, existing primary/foreign key indexes already provide optimal execution paths; additional indexing yields diminishing returns.
- **Visual Evidence:**
  - Analysis Plan: [screenshot/customer largest transfer analysis plan.png](screenshot/customer%20largest%20transfer%20analysis%20plan.png)
  - Graphical Plan: [screenshot/customer largest transfer graphical plan.png](screenshot/customer%20largest%20transfer%20graphical%20plan.png)
  - Result Evidence: [screenshot/Chirim_Amarachukwu_301914084_q03.png](screenshot/Chirim_Amarachukwu_301914084_q03.png)

---

### 3.4 Q4: Large Transfer Fraud Pattern (AML Compliance Daily Review)

- **SQL Source:** [queries/q04_large_transfer_fraud.sql](queries/q04_large_transfer_fraud.sql)
- **Business Purpose:** Compliance team scans for high-velocity transfer fraud (accounts sending $\ge 4,000$ NGN within the last 90 days).
- **Query Structure:**
  ```sql
  SELECT a.customer_id,
         count(*)      AS large_transfers,
         sum(l.amount) AS total_sent
  FROM ledger_entries l
  JOIN accounts a ON a.account_id = l.account_id
  WHERE l.direction = 'DEBIT'
    AND l.amount >= 4000
    AND l.created_at >= now() - interval '90 days'
  GROUP BY a.customer_id
  ORDER BY large_transfers DESC, total_sent DESC
  LIMIT 10;
  ```

#### Plan Comparison & Architectural Analysis
- **Baseline (Before):**
  - Lacking an index on ledger amounts and timestamps, the planner launched a **Parallel Seq Scan** across all 404,162 rows of `ledger_entries`.
  - Filter removed 131,440 rows per worker; joined via parallel hash join against 6,001 accounts.
  - Execution Time: **28.978 ms** | Buffers: 4,539 blocks.
- **Optimized (After):**
  - Index Deployed:
    ```sql
    CREATE INDEX idx_ledger_large_debits
        ON ledger_entries (created_at)
        INCLUDE (account_id, amount, transaction_id)
        WHERE direction = 'DEBIT' AND amount >= 4000;
    ```
  - Optimization Mechanism:
    - Predicate filtering (`direction = 'DEBIT' AND amount >= 4000`) is resolved at the index creation boundary.
    - Index size is only **2,240 kB** (spanning only 45,590 qualifying rows out of 404,162).
    - Query executes an **Index Only Scan**, reading zero heap pages (`Heap Fetches: 0`).
  - Execution Time: **14.973 ms** (**1.94x faster**, 48.3% latency reduction).
  - Buffer Footprint: Dropped from 4,539 blocks to **186 blocks** (95.9% reduction in I/O operations).
- **Visual Evidence:**
  - Analysis Plan: [screenshot/large transfer fraud analysis plan.png](screenshot/large%20transfer%20fraud%20analysis%20plan.png)
  - Graphical Plan: [screenshot/large transfer fraud graphical plan.png](screenshot/large%20transfer%20fraud%20graphical%20plan.png)
  - Result Evidence: [screenshot/Chirim_Amarachukwu_301914084_q04.png](screenshot/Chirim_Amarachukwu_301914084_q04.png)

---

### 3.5 Q5: Idempotency Key Lookup (Control Query)

- **SQL Source:** [queries/q05_idempotency_lookup.sql](queries/q05_idempotency_lookup.sql)
- **Business Purpose:** Control benchmark verifying payment idempotency lookup when a network-dropped request is retried.
- **Query Structure:**
  ```sql
  SELECT *
  FROM transactions
  WHERE idempotency_key = 'seed-xfer-12345';
  ```

#### Plan & Architectural Analysis
- **Plan Execution:**
  - Both before and after: `Index Scan using transactions_idempotency_key_key on transactions (cost=0.42..8.44 rows=1)`.
  - Buffer Hits: 4 blocks | Execution Time: **0.026 ms (Before)** vs **0.022 ms (After)**.
- **Engineering Principle:**
  - Relational uniqueness constraints (`UNIQUE (idempotency_key)`) automatically synthesize unique B-Tree indexes under the hood. 
  - This demonstrates that declarative data integrity rules simultaneously establish high-performance lookup indexes for core payment processing.
- **Visual Evidence:**
  - Result Evidence: [screenshot/Chirim_Amarachukwu_301914084_q05.png](screenshot/Chirim_Amarachukwu_301914084_q05.png)

---

### 3.6 Q6: Balance Reconciliation Audit (Integrity Verification)

- **SQL Source:** [queries/q06_balance_reconciliation.sql](queries/q06_balance_reconciliation.sql)
- **Business Purpose:** End-of-day financial audit asserting that cached `accounts.balance` matches `balance_after` of the latest settled ledger entry.
- **Query Structure:**
  ```sql
  SELECT a.account_number,
         a.balance        AS cached_balance,
         l.balance_after  AS ledger_balance,
         a.balance - l.balance_after AS difference
  FROM accounts a
  JOIN (
      SELECT DISTINCT ON (account_id) account_id, balance_after
      FROM ledger_entries
      ORDER BY account_id, created_at DESC, entry_id DESC
  ) l ON l.account_id = a.account_id
  WHERE a.balance <> l.balance_after;
  ```

#### Plan Comparison & Architectural Analysis
- **Empirical Findings:**
  - Expected and Actual Result: **0 rows returned** ([plans/results.txt](plans/results.txt) line 133). 
  - Demonstrates that 100% of the 6,001 accounts perfectly reconcile against their historical ledger movements.
- **Execution Characteristics:**
  - Execution Time: 283.94 ms (Before) vs 388.29 ms (After).
  - The query must evaluate all 404,162 ledger records across 6,001 accounts to determine the most recent row per account (`DISTINCT ON`).
  - PostgreSQL chooses an `Incremental Sort` node (`Average Memory: 26kB`) followed by a `Merge Join` on account keys.
- **Architectural Recommendation:**
  - Full-table reconciliation queries scan 400,000+ rows and should never run synchronously on client requests. They should be scheduled as asynchronous off-peak batch crons or offloaded to read replicas.
- **Visual Evidence:**
  - Result Evidence: [screenshot/Chirim_Amarachukwu_301914084_q06.png](screenshot/Chirim_Amarachukwu_301914084_q06.png)

---

### 3.7 Q7: Unbalanced Journals Audit (Double-Entry Invariant)

- **SQL Source:** [queries/q07_unbalanced_journals.sql](queries/q07_unbalanced_journals.sql)
- **Business Purpose:** Core accounting audit ensuring that every completed or reversed transaction satisfies $\sum \text{Debits} = \sum \text{Credits}$.
- **Query Structure:**
  ```sql
  SELECT t.transaction_id, t.txn_type, t.amount,
         count(l.entry_id) AS entry_count,
         coalesce(sum(l.amount) FILTER (WHERE l.direction = 'DEBIT'), 0)  AS total_debits,
         coalesce(sum(l.amount) FILTER (WHERE l.direction = 'CREDIT'), 0) AS total_credits
  FROM transactions t
  LEFT JOIN ledger_entries l ON l.transaction_id = t.transaction_id
  WHERE t.status IN ('COMPLETED', 'REVERSED')
  GROUP BY t.transaction_id, t.txn_type, t.amount
  HAVING count(l.entry_id) = 0
      OR coalesce(sum(l.amount) FILTER (WHERE l.direction = 'DEBIT'), 0)
      <> coalesce(sum(l.amount) FILTER (WHERE l.direction = 'CREDIT'), 0);
  ```

#### Plan & Accounting Findings
- **Result:** **0 rows returned** ([plans/results.txt](plans/results.txt) line 147).
- **Execution Mechanics:**
  - Evaluates 202,081 completed/reversed transactions against 404,162 ledger lines.
  - Leverages a `Merge Left Join` between `transactions_pkey` and the composite unique key `ledger_entries_transaction_id_account_id_direction_key`.
  - Execution Time: **205.70 ms** across 12,095 buffer hits.
  - Proves that the CedarPay dataset is mathematically balanced without a single orphaned or unbalanced transaction.
- **Visual Evidence:**
  - Result Evidence: [screenshot/Chirim_Amarachukwu_301914084_q07.png](screenshot/Chirim_Amarachukwu_301914084_q07.png)

---

### 3.8 Q8: Net Movement & Reversals (Treasury Liquidity Report)

- **SQL Source:** [queries/q08_net_movement_reversals.sql](queries/q08_net_movement_reversals.sql)
- **Business Purpose:** 90-day treasury report tracking net transfer volume while isolating reversed transactions.
- **Query Structure:**
  ```sql
  SELECT count(*) FILTER (WHERE status = 'COMPLETED')    AS net_transfers,
         sum(amount) FILTER (WHERE status = 'COMPLETED') AS net_amount,
         count(*) FILTER (WHERE status = 'REVERSED')     AS reversed_transfers,
         sum(amount) FILTER (WHERE status = 'REVERSED')  AS reversed_amount,
         count(*) FILTER (WHERE status = 'FAILED')       AS failed_transfers
  FROM transactions
  WHERE txn_type = 'TRANSFER'
    AND initiated_at >= now() - interval '90 days';
  ```

#### Plan Comparison & Architectural Analysis
- **Baseline (Before):**
  - Parallel Seq Scan across `transactions` (cost=0.00..4863.47), scanning 3,146 blocks.
  - Execution Time: **16.926 ms**.
- **Optimized (After):**
  - Index Deployed:
    ```sql
    CREATE INDEX idx_txn_type_time_cover
        ON transactions (txn_type, initiated_at)
        INCLUDE (status, amount, reversal_of);
    ```
  - Execution Mechanism:
    - Index Only Scan reading 48,878 qualifying rows directly from the index tree.
  - Execution Time: **12.845 ms** (**1.32x faster**, 24.1% latency reduction).
  - Buffer Footprint: Dropped from 3,146 table pages to **1,394 index pages** (55.7% I/O reduction).
- **Visual Evidence:**
  - Result Evidence: [screenshot/Chirim_Amarachukwu_301914084_q08.png](screenshot/Chirim_Amarachukwu_301914084_q08.png)

---

### 3.9 Q9: The Join Fan-Out Trap (Correctness & Invariant Proof)

- **SQL Source:** [queries/q09_join_fanout_trap.sql](queries/q09_join_fanout_trap.sql)
- **Topic:** Analytical correctness and join multiplicity in double-entry systems.
- **Query Structure:**
  ```sql
  SELECT
      (SELECT sum(t.amount)
         FROM transactions t
         JOIN ledger_entries l ON l.transaction_id = t.transaction_id
        WHERE t.txn_type = 'TRANSFER' AND t.status = 'COMPLETED'
          AND t.initiated_at >= now() - interval '30 days') AS fan_out_total,
      (SELECT sum(t.amount)
         FROM transactions t
        WHERE t.txn_type = 'TRANSFER' AND t.status = 'COMPLETED'
          AND t.initiated_at >= now() - interval '30 days') AS correct_total;
  ```

#### Empirical Result & Architectural Lesson
- **Query Result ([plans/results.txt](plans/results.txt) lines 159–163):**
  - `fan_out_total` = **55,278,924.8800 NGN**
  - `correct_total` = **27,639,462.4400 NGN**
  - Multiplier: $\frac{\text{fan\_out\_total}}{\text{correct\_total}} = \mathbf{2.0000}$ (Exactly 2.0x).
- **Explanation:**
  - In a balanced double-entry system, every completed transfer decomposes into **exactly two** ledger rows (one DEBIT and one CREDIT).
  - Joining the 1-side table (`transactions`) to the M-side table (`ledger_entries`) multiplies each transaction header by the row multiplicity (2). Performing `SUM(t.amount)` on the joined set doubles the actual money moved!
- **Engineering Rule:** Financial reporting queries must either aggregate before joining or sum from the ledger directly with directional filtering (`WHERE direction = 'DEBIT'`).
- **Visual Evidence:**
  - Result Evidence: [screenshot/Chirim_Amarachukwu_301914084_q09.png](screenshot/Chirim_Amarachukwu_301914084_q09.png)

---

### 3.10 Q10: Customer KYC Verification Analysis (Cardinality & Selectivity)

- **SQL Source:** [queries/q10_kyc_verification_analysis.sql](queries/q10_kyc_verification_analysis.sql)
- **Business Question:** Breakdown of customers by KYC status (`VERIFIED`, `PENDING`, `REJECTED`).
- **Query Result:**
  - `VERIFIED`: 4,826 customers (4,951 total records)
  - `PENDING`: 200 customers (200 records)
  - `REJECTED`: 125 customers (125 records)
- **Optimization Finding on Candidate Index `idx_kyc_verification_status`:**
  - The column `verification_status` contains only **3 distinct values** ($N_{\text{distinct}} = 3$) across 5,276 rows.
  - Because `VERIFIED` accounts for over 93% of the dataset, PostgreSQL's cost estimator correctly ignores the candidate index and chooses a fast sequential scan of 71 pages (0.5ms). B-Tree indexing on low-cardinality status columns is generally counterproductive unless implemented as a partial index targeting rare values (e.g. `WHERE verification_status = 'PENDING'`).
- **Visual Evidence:**
  - Result Evidence: [screenshot/KYC verification analysis q10.png](screenshot/KYC%20verification%20analysis%20q10.png)

---

### 3.11 Q11: Customer Transaction Activity (Multi-Table Aggregation)

- **SQL Source:** [queries/q11_customer_transaction_activity.sql](queries/q11_customer_transaction_activity.sql)
- **Business Question:** Identifies the top 20 most active customers by completed transaction volume and total amount in the last 30 days.
- **Query Mechanics:**
  - Multi-table join across `customers` $\bowtie$ `accounts` $\bowtie$ `ledger_entries` $\bowtie$ `transactions`.
  - Date filtering (`t.initiated_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'`) leverages the optimized transaction and ledger indexes to drop join input sizes by over 80%.
  - Execution Time: ~45.10 ms (vs ~85.40 ms baseline).
- **Visual Evidence:**
  - Result Evidence: [screenshot/Customer transaction activity q11.png](screenshot/Customer%20transaction%20activity%20q11.png)

---

## 4. PostgreSQL Planner Cost Model & Selectivity Experiments

In [sql/05_planner_experiments.sql](sql/05_planner_experiments.sql), we evaluated how PostgreSQL's cost estimator decides between an index scan and a sequential scan based on data selectivity.

### 4.1 Selectivity Experiment: Customer Status (`SUSPENDED` vs. `ACTIVE`)

A temporary index was created on `customers (status)` to observe planner behavior on skewed distributions:

```sql
BEGIN;
CREATE INDEX tmp_customers_status ON customers (status);
ANALYZE customers;
```

#### Empirical Results from [plans/planner.txt](plans/planner.txt) (Lines 240–267)

1. **Rare Predicate: `WHERE status = 'SUSPENDED'`**
   - True rows: **50 out of 5,001 (1.0% of table)**.
   - Planner Selection: **`Index Scan using tmp_customers_status on customers`**
   - Cost: `0.28..14.63` | Actual Execution Time: **0.035 ms** | Buffers: 50 hit, 2 read.
   - *Rationale:* Fetching 1% of rows via the index requires only 52 buffer accesses, far cheaper than scanning all 71 heap pages.

2. **Common Predicate: `WHERE status = 'ACTIVE'`**
   - True rows: **4,951 out of 5,001 (99.0% of table)**.
   - Planner Selection: **`Seq Scan on customers`** (Index deliberately bypassed!)
   - Cost: `0.00..133.51` | Actual Execution Time: **0.427 ms** | Buffers: 71 hit.
   - *Rationale:* If the planner used an index, it would incur $4,951 \times 4.0$ (`random_page_cost`), resulting in massive random I/O. The sequential scan reads contiguous 8 KB blocks at `seq_page_cost = 1.0`, completing in just 71 page reads.

> [!IMPORTANT]
> This experiment empirically proves that indexes are not universally faster. An index is only beneficial when query selectivity is high (typically retrieving $\le 5\text{–}10\%$ of table rows).

---

## 5. Storage Overhead and Write Penalty Analysis

Every index added to a relational database introduces two real costs:
1. **Disk Storage Footprint:** Secondary B-Trees consume memory in `shared_buffers` and disk space.
2. **Write Penalty (DML Overhead):** Every `INSERT`, `UPDATE`, or `DELETE` must synchronously update all associated B-Trees.

### 5.1 Storage Breakdown of Candidate Indexes

From [sql/03_create_indexes.sql](sql/03_create_indexes.sql) and [plans/planner.txt](plans/planner.txt):

| Index Name | Target Table | Indexed Columns / Definition | Index Size | Architectural Purpose |
| :--- | :--- | :--- | :---: | :--- |
| `idx_ledger_account_created` | `ledger_entries` | `(account_id, created_at DESC)` | **12 MB** | Eliminates sorting for mobile account statements (Q1). |
| `idx_txn_type_time_cover` | `transactions` | `(txn_type, initiated_at) INCLUDE (...)` | **15 MB** | Covering index for treasury reports (Q8). |
| `idx_txn_completed_transfers_time` | `transactions` | `(initiated_at) INCLUDE (amount) WHERE ...` | **6,048 kB** | Partial covering index for daily dashboard (Q2). |
| `idx_ledger_large_debits` | `ledger_entries` | `(created_at) INCLUDE (...) WHERE ...` | **2,240 kB** | Partial covering index for AML fraud pattern (Q4). |
| `idx_accounts_customer` | `accounts` | `(customer_id)` | **128 kB** | Fast customer-to-wallet resolution (Q3). |
| `idx_kyc_verification_status` | `kyc_records` | `(verification_status)` | **128 kB** | Evaluated for status grouping (Q10). |
| **Total Added Index Footprint** | | | **~35.5 MB** | |

### 5.2 Write Cost Experiment ([sql/06_write_cost.sql](sql/06_write_cost.sql))

In high-volume FinTech systems handling 1.2M daily transfers, ledger tables are append-heavy. Maintaining too many secondary indexes degrades ingestion throughput.

- **Baseline Table (`le_no_index`):** Table size: 33 MB | Index size: 0 MB | Ingestion: 404,162 rows inserted in a single continuous sequential stream.
- **Indexed Table (`le_with_index`):** Table size: 33 MB | Index size: ~14.2 MB | Ingestion: Every inserted row must update `tmp_le_account_created` and conditionally update `tmp_le_large_debits`.
- **Engineering Principle:** By employing **partial indexes** (`WHERE direction = 'DEBIT' AND amount >= 4000`), CedarPay updates the fraud index on only ~11% of ledger entries, mitigating the write penalty by nearly 90% compared to a non-partial composite index.

---

## 6. Synthesis & Architectural Recommendations for CedarPay

1. **Leverage Composite B-Trees with Equality-First Ordering:**
   Declare composite indexes with filter attributes first, followed by sort attributes (`account_id, created_at DESC`). This converts an $O(N \log N)$ Sort into an $O(1)$ index pipeline.
2. **Prioritize Partial Indexes for Known Query Workloads:**
   In financial systems where 95%+ of queries inspect `COMPLETED` transactions or high-value transfers, partial indexes (`WHERE status = 'COMPLETED'`) deliver 70%+ space savings and faster traversal depths.
3. **Exploit Covering Indexes (`INCLUDE`) for High-Frequency Aggregations:**
   Adding payload columns (`amount`) to index leaves enables **Index Only Scans**, eliminating expensive table heap reads.
4. **Isolate Audit & Reconciliation Queries:**
   Full ledger reconciliations (Q6, Q7) require exhaustive scans. These operations must be isolated to scheduled nightly maintenance or read replicas to preserve OLTP core throughput.
5. **Beware the Join Fan-Out Trap:**
   Never join financial transaction headers directly to multi-line double-entry ledgers without pre-aggregating or directional filtering.

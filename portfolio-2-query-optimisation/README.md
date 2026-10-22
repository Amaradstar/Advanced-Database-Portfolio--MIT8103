# Portfolio 2: Query Processing and Optimisation – CedarPay

**Course:** Advanced Database Systems (MIT 8103)  
**Student Name:** Amarachukwu Chirim  
**Student ID:** 301914084  
**Case Study:** CedarPay Technologies Ltd. (Simulated Nigerian FinTech Platform)  
**Target RDBMS:** PostgreSQL 18.6 on macOS (Apple Silicon arm64)  
**Database Name:** `cedarpay_db`  
**Dataset Scale:** ~5,001 Customers | 6,001 Accounts | 206,096 Transactions | 404,162 Ledger Entries  

---

## 1. Overview & Objectives

Portfolio 2 investigates query processing, execution plan analysis, cost-based optimization, and index design for **CedarPay**, an enterprise-grade digital payment and wallet platform. 

Building directly upon the relational foundation established in [Portfolio 1](../portfolio-1-database-design/), this module evaluates how PostgreSQL's query planner handles real-world FinTech workloads operating over hundreds of thousands of transactions and ledger records.

### Key Objectives
1. **Execution Plan Analysis (`EXPLAIN ANALYZE BUFFERS`):** Deconstruct query execution nodes (Sequential Scans, Index Scans, Index-Only Scans, Bitmap Scans, Hash Joins, Nested Loops, and Merge Joins).
2. **Targeted Index Engineering:** Design and benchmark Composite, Partial, and Covering (`INCLUDE`) B-Tree indexes tailored to high-frequency payment paths.
3. **Financial Invariant & Correctness Auditing:** Validate zero-discrepancy reconciliation audits and analyze the dangerous **Join Fan-Out Trap** inherent in double-entry ledger structures.
4. **Planner Cost Modeling & Selectivity:** Measure how data skew and predicate selectivity dictate optimizer decisions (`seq_page_cost` vs `random_page_cost`).
5. **Storage & Write-Overhead Trade-Offs:** Quantify the physical footprint of secondary indexes and the write penalty incurred during high-velocity ledger inserts.

---

## 2. Directory Structure & Artifact Map

This directory contains eleven benchmark queries, seven automated execution scripts, baseline/optimized execution plans, empirical results, and 27 execution screenshots:

```text
portfolio-2-query-optimisation/
├── README.md                                # Master Portfolio 2 documentation (this file)
├── performance-analysis.md                  # Comprehensive empirical performance report
├── queries/                                 # 11 Standalone SQL benchmark queries
│   ├── q01_account_statement.sql            # Q1: Mobile 50 most recent ledger entries
│   ├── q02_daily_transfer_totals.sql        # Q2: Daily completed transfers (last 30 days)
│   ├── q03_customer_largest_transfers.sql   # Q3: Dispute support - top 10 transfers
│   ├── q04_large_transfer_fraud.sql         # Q4: AML fraud review (debits >= 4000 NGN)
│   ├── q05_idempotency_lookup.sql           # Q5: Control query - payment idempotency
│   ├── q06_balance_reconciliation.sql       # Q6: End-of-day cached vs ledger audit
│   ├── q07_unbalanced_journals.sql          # Q7: Double-entry debit/credit invariant audit
│   ├── q08_net_movement_reversals.sql       # Q8: 90-day treasury report with reversals
│   ├── q09_join_fanout_trap.sql             # Q9: Algorithmic join fan-out correctness
│   ├── q10_kyc_verification_analysis.sql    # Q10: Customer KYC verification status breakdown
│   └── q11_customer_transaction_activity.sql# Q11: Top 20 customer activity aggregation
├── sql/                                     # Automated management and test scripts
│   ├── 00_data_check.sql                    # Verifies Portfolio 1 seed dataset row counts
│   ├── 01_capture_plans.sql                 # Runs EXPLAIN (ANALYZE, BUFFERS) across queries
│   ├── 02_query_results.sql                 # Executes and records raw query output sets
│   ├── 03_create_indexes.sql                # Deploys candidate optimization indexes
│   ├── 04_drop_indexes.sql                  # Tears down indexes to restore baseline state
│   ├── 05_planner_experiments.sql           # Tests cost parameters & selectivity heuristics
│   └── 06_write_cost.sql                    # Measures index write penalty and size overhead
├── plans/                                   # Raw execution plan outputs and logs
│   ├── before.txt                           # Baseline plans with NO secondary indexes
│   ├── after.txt                            # Optimized plans with candidate indexes active
│   ├── planner.txt                          # Cost model settings and selectivity experiments
│   └── results.txt                          # Formatted result sets for all 11 queries
└── screenshot/                              # 27 Verified execution screenshots from pgAdmin 4
```

---

## 3. Query Catalog & Workload Profiles

The benchmark suite simulates four operational tiers of CedarPay's neo-banking platform:

| Query ID | File Link | Operational Domain | Business Query Description | Key Technical Feature |
| :---: | :--- | :--- | :--- | :--- |
| **Q1** | [q01](queries/q01_account_statement.sql) | Mobile Banking | 50 most recent ledger lines for an account. | Composite Index eliminates Sort node |
| **Q2** | [q02](queries/q02_daily_transfer_totals.sql) | Finance Dashboard | Daily completed transfer counts & amounts (30 days). | Partial Covering Index-Only Scan |
| **Q3** | [q03](queries/q03_customer_largest_transfers.sql) | Dispute Resolution | 10 largest outgoing transfers for a customer. | 3-table join with Top-N heapsort |
| **Q4** | [q04](queries/q04_large_transfer_fraud.sql) | AML & Compliance | Customers with largest transfers ($\ge 4,000$ NGN). | Partial Index on high-value debits |
| **Q5** | [q05](queries/q05_idempotency_lookup.sql) | Core Banking | Control query: Lookup by idempotency key. | Instant $O(\log N)$ Unique Index Scan |
| **Q6** | [q06](queries/q06_balance_reconciliation.sql) | Accounting Audit | Asserts `accounts.balance` matches latest `balance_after`. | `DISTINCT ON` Incremental Sort Merge Join |
| **Q7** | [q07](queries/q07_unbalanced_journals.sql) | Core Invariant | Asserts $\sum \text{Debits} = \sum \text{Credits}$ per transaction. | 202k-row Merge Join with 0 violations |
| **Q8** | [q08](queries/q08_net_movement_reversals.sql) | Treasury Reporting | 90-day transfer volume separating reversed amounts. | Covering Index on `(txn_type, initiated_at)` |
| **Q9** | [q09](queries/q09_join_fanout_trap.sql) | Financial Integrity | Proves 1:M join fan-out doubles transaction sums. | Algorithmic correctness demonstration |
| **Q10** | [q10](queries/q10_kyc_verification_analysis.sql) | Risk & KYC | Customer count by KYC status (`VERIFIED`, `PENDING`). | Low-cardinality index evaluation |
| **Q11** | [q11](queries/q11_customer_transaction_activity.sql) | Business Intelligence | Top 20 customers by completed volume (30 days). | 4-table join with aggregation & LIMIT |

---

## 4. Indexing Strategy & Schema Enhancements

Candidate indexes were deployed via [sql/03_create_indexes.sql](sql/03_create_indexes.sql) to target specific bottleneck patterns without indiscriminately burdening write throughput:

```sql
-- 1. Q1: Composite index matching filter + ordering
CREATE INDEX idx_ledger_account_created
    ON ledger_entries (account_id, created_at DESC);

-- 2. Q3: Fast customer-to-wallet resolution
CREATE INDEX idx_accounts_customer
    ON accounts (customer_id);

-- 3. Q2: Partial covering index for completed transfers
CREATE INDEX idx_txn_completed_transfers_time
    ON transactions (initiated_at)
    INCLUDE (amount)
    WHERE txn_type = 'TRANSFER' AND status = 'COMPLETED';

-- 4. Q4: Partial covering index for AML fraud debits
CREATE INDEX idx_ledger_large_debits
    ON ledger_entries (created_at)
    INCLUDE (account_id, amount, transaction_id)
    WHERE direction = 'DEBIT' AND amount >= 4000;

-- 5. Q8: Covering index for treasury reports
CREATE INDEX idx_txn_type_time_cover
    ON transactions (txn_type, initiated_at)
    INCLUDE (status, amount, reversal_of);

-- 6. Q10: Candidate index for low-cardinality KYC status
CREATE INDEX idx_kyc_verification_status
    ON kyc_records (verification_status);
```

### Index Optimization Patterns Explained
1. **Composite Equality-First Indexing (`idx_ledger_account_created`):** Placing `account_id` before `created_at DESC` allows the B-Tree to seek directly to the customer's account entries and read them in reverse chronological order, eliminating in-memory sorting.
2. **Partial Indexing (`idx_txn_completed_transfers_time`, `idx_ledger_large_debits`):** Restricts indexed rows using a `WHERE` clause. The fraud index spans only **45,590 rows (2.2 MB)** instead of 404,162 rows (33 MB), dramatically saving RAM and write overhead.
3. **Covering Indexes (`INCLUDE`):** Stores payload attributes (`amount`, `status`) in index leaf pages, allowing PostgreSQL to perform **Index-Only Scans** without touching table heap pages.

---

## 5. Performance Benchmark Summary

For the full architectural write-up, refer to the [Performance Analysis Report](performance-analysis.md).

```
+---------------------------------------------------------------------------------------------------+
|                                  KEY PERFORMANCE HIGHLIGHTS                                       |
+---------------------------------------------------------------------------------------------------+
|  [Q1 Account Statement]       Latency: 6.13 ms -> 2.24 ms        Speedup: 2.74x (Sort eliminated) |
|  [Q2 Daily Transfer Totals]   Latency: 42.94 ms -> 12.33 ms      Speedup: 3.48x (89% less I/O)    |
|  [Q4 AML Fraud Pattern]       Latency: 28.98 ms -> 14.97 ms      Speedup: 1.94x (96% less I/O)    |
|  [Q5 Idempotency Lookup]      Latency: 0.026 ms -> 0.022 ms      O(log N) Unique B-Tree seek      |
|  [Q6 Balance Reconciliation]  Discrepancy: 0 accounts            100% Cache/Ledger Agreement      |
|  [Q7 Unbalanced Journals]     Unbalanced: 0 transactions         100% Double-Entry Compliance     |
|  [Q9 Join Fan-Out Trap]       Fan-Out Sum = 2.0x Correct Sum     Proves Multiplicity Hazard       |
+---------------------------------------------------------------------------------------------------+
```

---

## 6. Execution Guide & Reproduction Steps

To execute the Portfolio 2 test suite locally using `psql`:

```bash
# Connect to the CedarPay database
psql -U postgres -h localhost -d cedarpay_db

# 1. Verify Portfolio 1 seed dataset is present
\i portfolio-2-query-optimisation/sql/00_data_check.sql

# 2. Reset to baseline (ensure no secondary candidate indexes exist)
\i portfolio-2-query-optimisation/sql/04_drop_indexes.sql

# 3. Capture baseline query plans
\o portfolio-2-query-optimisation/plans/before.txt
\i portfolio-2-query-optimisation/sql/01_capture_plans.sql
\o

# 4. Deploy candidate indexes
\i portfolio-2-query-optimisation/sql/03_create_indexes.sql

# 5. Capture post-optimization query plans
\o portfolio-2-query-optimisation/plans/after.txt
\i portfolio-2-query-optimisation/sql/01_capture_plans.sql
\o

# 6. Capture query output sets
\o portfolio-2-query-optimisation/plans/results.txt
\i portfolio-2-query-optimisation/sql/02_query_results.sql
\o

# 7. Run planner cost & selectivity experiments
\o portfolio-2-query-optimisation/plans/planner.txt
\i portfolio-2-query-optimisation/sql/05_planner_experiments.sql
\o

# 8. Measure index write cost and table size penalty
\i portfolio-2-query-optimisation/sql/06_write_cost.sql
```

---

## 7. Verification Evidence & Screenshot Index

All test results and query plans are verified through 27 high-resolution screenshots stored in the [screenshot/](screenshot/) directory:

### 7.1 Data Verification & Baseline Execution
- [Data check.png](screenshot/Data%20check.png): Verification of 5,001 customers, 6,001 accounts, 206k transactions, 404k ledger lines.
- [Baseline plan with no indexes.png](screenshot/Baseline%20plan%20with%20no%20indexes.png): Baseline EXPLAIN output with secondary indexes dropped.
- [create indexes.png](screenshot/create%20indexes.png): Successful deployment of all candidate indexes.
- [after index plan optimisation.png](screenshot/after%20index%20plan%20optimisation.png): Execution plan improvements with indexes active.

### 7.2 Individual Query Results (Q1 through Q11)
- [Q1 Account Statement](screenshot/Chirim_Amarachukwu_301914084_q01.png): First 50 ledger rows for account `2200001001`.
- [Q2 Daily Transfer Totals](screenshot/Chirim_Amarachukwu_301914084_q02.png): 29 days of rolling completed transfer totals.
- [Q3 Customer Largest Transfers](screenshot/Chirim_Amarachukwu_301914084_q03.png): Top 10 debit transfers for customer `1001`.
- [Q4 Large Transfer Fraud](screenshot/Chirim_Amarachukwu_301914084_q04.png): Customers with largest transfer counts ($\ge 4,000$ NGN).
- [Q5 Idempotency Lookup](screenshot/Chirim_Amarachukwu_301914084_q05.png): Instantaneous point lookup for `seed-xfer-12345`.
- [Q6 Balance Reconciliation](screenshot/Chirim_Amarachukwu_301914084_q06.png): Zero rows returned, confirming perfect reconciliation.
- [Q7 Unbalanced Journals](screenshot/Chirim_Amarachukwu_301914084_q07.png): Zero rows returned, confirming zero unbalanced transactions.
- [Q8 Net Movement & Reversals](screenshot/Chirim_Amarachukwu_301914084_q08.png): 90-day treasury report figures.
- [Q9 Join Fan-Out Trap](screenshot/Chirim_Amarachukwu_301914084_q09.png): Displays `fan_out_total` (55.2M NGN) vs `correct_total` (27.6M NGN).
- [Q10 KYC Verification Analysis](screenshot/KYC%20verification%20analysis%20q10.png): Breakdown of customers across KYC statuses.
- [Q11 Customer Transaction Activity](screenshot/Customer%20transaction%20activity%20q11.png): Top 20 customers by completed transaction amount.

### 7.3 Detailed Analytical & Graphical Plans
- **Account Statement (Q1):**
  - [Analysis Plan](screenshot/account%20statement%20analysis%20plan.png) | [Graphical Plan](screenshot/account%20statement%20graphical%20plan.png)
  - [Drop Index Analysis](screenshot/drop%20index-account%20statement%20analysis%20plan.png) | [Drop Index Graphical](screenshot/drop%20index-account%20statement%20graphical%20plan.png)
- **Daily Transfer Totals (Q2):**
  - [Analysis Plan](screenshot/daily%20transfer%20analysis%20plan.png) | [Graphical Plan](screenshot/daily%20transfer%20graphical%20plan.png)
  - [Drop Index Analysis](screenshot/drop%20index-daily%20transfer%20total%20analysis%20plan.png) | [Drop Index Graphical](screenshot/drop%20index-%20daily%20transfer%20total%20graphical%20plan.png)
- **Customer Largest Transfers (Q3):**
  - [Analysis Plan](screenshot/customer%20largest%20transfer%20analysis%20plan.png) | [Graphical Plan](screenshot/customer%20largest%20transfer%20graphical%20plan.png)
- **Large Transfer Fraud (Q4):**
  - [Analysis Plan](screenshot/large%20transfer%20fraud%20analysis%20plan.png) | [Graphical Plan](screenshot/large%20transfer%20fraud%20graphical%20plan.png)

---

## 8. Alignment with Portfolio 3 (Concurrency & Transactions)

The query performance benchmarks in Portfolio 2 directly prepare the architecture for **Portfolio 3: Transactions and Concurrency Control**:
- **Row-Level Locking Overhead:** The selective indexes developed here (`idx_accounts_customer`, `idx_ledger_account_created`) will ensure that concurrent `SELECT ... FOR UPDATE` operations lock only specific account rows without escalating to table locks.
- **Race Condition Prevention:** The low-latency lookup paths tested in Q1 and Q5 enable high-throughput validation of available balances prior to committing transfer transactions.
- **Audit Immutability:** The append-only ledger structure benchmarked in Q6 and Q7 provides the transactional foundation for testing isolation levels (`READ COMMITTED` vs `SERIALIZABLE`) and deadlock handling.

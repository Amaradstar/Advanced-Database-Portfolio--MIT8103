# Advanced Database Systems Synthesis Report — CedarPay Portfolio
**Course:** MIT 8103 Advanced Database Systems (40 Marks Continuous Assessment)  
**Academic Session:** 2026/2027 Academic Session (September Cohort)  
**Institution:** Miva Open University — School of Post Graduate Studies  
**Student Name:** Chirim Amarachukwu  
**Student ID:** 301914084  
**GitHub Repository:** [https://github.com/Amaradstar/Advanced-Database-Portfolio--MIT8103](https://github.com/Amaradstar/Advanced-Database-Portfolio--MIT8103)  
**Permanent Branch:** `main`  

---

## 1. Case Study & Architecture Overview
**CedarPay Technologies Ltd.** is a simulated Nigerian digital wallet, payment gateway, and financial technology services provider headquartered in Lagos, Nigeria. The platform facilitates peer-to-peer (P2P) transfers, bill payments, and merchant settlement across high-concurrency mobile and web endpoints. Operating within the Nigerian fintech regulatory landscape requires adherence to Central Bank of Nigeria (CBN) guidelines, NIBSS 10-digit NUBAN numbering, tiered KYC (Know Your Customer) rules, and the Nigeria Data Protection Act (NDPR).

To satisfy the contradictory demands of strict financial accounting (zero tolerance for data loss or phantom reads) and high-velocity user activity logging, CedarPay employs a **hybrid polyglot persistence architecture**:
1. **Relational Financial Ledger (PostgreSQL 18 / PostgreSQL 16 Cluster):** Acts as the authoritative system of record for accounts, customers, transactions, and immutable double-entry ledger postings. Every fund transfer produces two balancing rows (`DEBIT` and `CREDIT`) ensuring that the sum of all movements across the ledger equals zero.
2. **Semi-Structured Operational Store (MongoDB & MongoDB Atlas M0 Replica Set):** Acts as the system of engagement for polystructured customer data including multi-tiered KYC documents, variable audit trails, and time-expiring login sessions.

---

## 2. Executive Summaries of Portfolio Components

### Portfolio 1: Relational Database Design and Modelling
- **Objective:** Establish the normalized relational schema and data-level integrity guarantees for CedarPay.
- **Implementation:** Designed an 8-table relational schema (`customers`, `kyc_records`, `accounts`, `beneficiaries`, `cards`, `transactions`, `ledger_entries`, `fraud_flags`) normalized to Boyce-Codd Normal Form (BCNF). Implemented primary keys using identity columns, foreign keys with `ON DELETE RESTRICT` to prevent orphan financial records, and 10-digit NUBAN regex constraints (`^[0-9]{10}$`).
- **Controlled Denormalization:** Maintained a cached `balance` in `accounts` accompanied by an immutable `ledger_entries` audit log. This guarantees $O(1)$ balance lookups for mobile wallet screens while preserving full double-entry auditability. Seeded with 5,001 customers, 6,001 accounts, 206,096 transactions, and 404,162 ledger rows.

### Portfolio 2: Query Processing and Optimisation
- **Objective:** Analyze PostgreSQL cost-based query execution plans and design an optimal B-Tree index configuration.
- **Implementation:** Formulated 11 mission-critical workload queries spanning statement retrieval (Q1), daily reconciliation (Q2), fraud detection (Q4), idempotency checks (Q5), and balance reconciliation (Q6). 
- **Benchmark Findings:** Using `EXPLAIN (ANALYZE, BUFFERS)`, queries demonstrated dramatic performance improvements. Q1 latency dropped by 63.5% (6.13 ms to 2.24 ms) via an index scan; Q2 dropped by 71.3% (42.94 ms to 12.33 ms) using a partial index on completed transfers; and Q4 dropped by 48.3% using a covering index (`INCLUDE (amount)`). A write-cost experiment quantified the insertion overhead of auxiliary indexes to establish balanced production trade-offs.

### Portfolio 3: Transactions and Concurrency Control
- **Objective:** Guarantee ACID properties and prevent concurrency anomalies in financial fund transfers.
- **Implementation:** Developed an atomic PL/pgSQL function (`transfer_funds`) incorporating explicit `BEGIN/COMMIT/ROLLBACK` logic, balance verification, idempotency checking, and row-level locking via `SELECT ... FOR UPDATE`.
- **Concurrency & Deadlock Resolution:** Compared Read Committed and Repeatable Read isolation levels across concurrent sessions. Reproducing an opposite-order locking scenario demonstrated how uncoordinated transactions trigger `deadlock detected (SQLSTATE 40P01)`. By enforcing a deterministic lock acquisition sequence (`ORDER BY account_id ASC`), concurrent competing transfers wait safely in queue and execute without deadlocks.

### Portfolio 4: NoSQL and Advanced Data Models
- **Objective:** Implement MongoDB document storage for flexible KYC and audit event pipelines.
- **Implementation:** Configured `CedarPay_db` with native `$jsonSchema` validators for `kyc_profiles`, `audit_events`, and `login_sessions`, validating BSON types and enums (triggering Error Code 121 on invalid documents). Seeded 5,000 KYC profiles and 100,000 audit events.
- **Aggregation & Indexing:** Executed complex multi-stage aggregation pipelines (`$match`, `$group`, `$sort`, `$project`) to analyze KYC verification funnels and rank top transaction cities. Deployed single-field, compound, unique, and TTL indexes (expiring sessions after 30 days). Query analysis via `explain("executionStats")` demonstrated an examination drop from 100,000 documents (`COLLSCAN`) to 16 documents (`IXSCAN`).

### Portfolio 5: Distributed and Cloud Databases
- **Objective:** Evaluate distributed database availability, streaming replication, partitioning, and cloud replica sets.
- **Implementation:** Deployed a two-node PostgreSQL 16 cluster in Docker Compose featuring primary write nodes (port 5433) and physical streaming standby nodes (port 5434). Simulated replication lag using `pg_wal_replay_pause()` to observe stale reads, and demonstrated synchronous replication fail-safe behavior when the standby is offline. Conducted manual failover via `pg_promote()`.
- **Partitioning & Cloud Replica Sets:** Partitioned 404,164 ledger rows across four hash partitions on `account_id`, proving declarative partition pruning via `EXPLAIN`. Concurrently deployed a 3-node MongoDB Atlas replica set in AWS Paris, demonstrating majority write acknowledgement (`w: "majority"`) and consistent secondary reads (`readPreference: "secondaryPreferred"`).

---

## 3. Technical Reflection & Individual Understanding
Undertaking this continuous assessment provided profound practical insights into the realities of modern database engineering:
1. **The Polyglot Dilemma & Application-Level Consistency:** Dividing data between PostgreSQL and MongoDB leverages the strengths of each system—relational rigidity for financial accounting and document elasticity for unstructured KYC records. However, because cross-engine foreign keys do not exist, referential integrity between MongoDB's `customer_id` and PostgreSQL's primary key must be actively enforced through application-level middleware and background reconciliation jobs.
2. **The CAP / PACELC Reality in Financial Systems:** In distributed replication, consistency and latency are fundamentally at odds. Asynchronous PostgreSQL replication provides rapid writes but permits stale reads and data loss during ungraceful failover. Synchronous replication ensures zero data loss ($RPO = 0$), but introduces network latency penalties and causes primary write hangs when the standby fails. In fintech, financial ledgers demand synchronous consistency, whereas high-volume audit event pipelines benefit from asynchronous durability.
3. **Partitioning Boundaries:** Declarative hash partitioning on `account_id` demonstrated substantial performance gains by pruning unneeded partitions during account-specific queries. However, queries lacking the partition key inevitably incur multi-partition scatter-gather overhead. Partitioning is not an automatic cure for scale; partition keys must be aligned with high-frequency query predicates.

---

## 4. Academic Integrity & AI-Use Declaration
I declare that this portfolio represents my original intellectual effort. Generative AI tools (OpenAI ChatGPT and Anthropic Claude) were consulted as research assistants for conceptual clarification, syntax troubleshooting, and editorial drafting assistance. All database architectures, container setups, SQL/JavaScript scripts, benchmark executions, and empirical screenshots were personally implemented, tested, and validated by the undersigned.

**Student Name:** Chirim Amarachukwu  
**Student ID:** 301914084  
**Date:** November 2026  
**Institution:** Miva Open University — School of Post Graduate Studies  

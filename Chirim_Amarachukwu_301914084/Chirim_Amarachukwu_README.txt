================================================================================
MIT 8103: ADVANCED DATABASE SYSTEMS — CONTINUOUS ASSESSMENT PORTFOLIO
ACADEMIC SESSION: 2026/2027 (SEPTEMBER COHORT)
MIVA OPEN UNIVERSITY — SCHOOL OF POST GRADUATE STUDIES
================================================================================

STUDENT AND SUBMISSION METADATA
--------------------------------------------------------------------------------
Student Surname:            Chirim
Student First Name:         Amarachukwu
Student ID:                 301914084
Student University Email:   achirim301914084@miva.university (or registered Miva account)
Personal/Git Email:         amarachirim@gmail.com
Programme:                  Master of Science in Information Technology / Computing
Course Code & Title:        MIT 8103: Advanced Database Systems
Assessment Type:            Individual Practical Database Portfolio (40 Marks Continuous Assessment)
Submission Channel:         Miva Learning Management System (LMS) & Official Submission Form
Chosen Case Study:          CedarPay Technologies Ltd. (Simulated Nigerian FinTech Platform)
Primary RDBMS:              PostgreSQL 18.6 (Local / macOS arm64) & PostgreSQL 16 (Docker Cluster)
Secondary Database (NoSQL): MongoDB 7.0/8.0 (mongosh & Compass) & MongoDB Atlas (M0 3-Node Cloud Replica Set)
GitHub Repository URL:      https://github.com/Amaradstar/Advanced-Database-Portfolio--MIT8103
Repository Branch:          main
Access Note for Assessor:   Grant assessor access to private repository if requested; all materials,
                            code, schemas, outputs, and screenshot evidence are self-contained here.

================================================================================
1. CASE STUDY STATEMENT & ARCHITECTURAL OVERVIEW (SECTION 2 COMPLIANCE)
================================================================================
In accordance with Section 2 of the MIT 8103 Course Specification, the selected
organisation and database operational parameters are formally declared as follows:

- Organisation Name:
  CedarPay Technologies Ltd. (Simulated Nigerian FinTech Platform).

- Nature of Business / System:
  Digital wallet, instant peer-to-peer (P2P) transfers, bill payments, and merchant
  collection platform operating in Lagos, Nigeria. Adheres to Central Bank of Nigeria
  (CBN) regulatory standards, NIBSS 10-digit NUBAN numbering, tiered KYC rules,
  and the Nigeria Data Protection Act (NDPR).

- Users of the Database:
  1. Retail customers and SME merchants (mobile and web transaction initiators).
  2. Customer support and dispute investigation agents (restricted read access).
  3. Compliance and Anti-Money Laundering (AML) officers (KYC and risk reviews).
  4. Treasury and finance accountants (balance reconciliation and ledger audits).
  5. Automated fraud detection workers (real-time risk scoring engines).

- Major Data Stored:
  Customers, tiered KYC verification submissions (NIN, BVN, Passport), wallet accounts
  denominated in NGN, beneficiaries, card metadata (PCI-DSS tokenized), transactions,
  immutable double-entry debit/credit ledger entries, fraud alert flags, semi-structured
  audit event logs, and time-expiring session tokens.

- Key Operations the Database Supports:
  Onboarding and verifying customer identity, atomic fund transfers with row-level
  locking, automated double-entry ledger balancing, end-of-day balance reconciliations,
  fraud velocity detection, account statement generation, and distributed streaming
  replication with failover and declarative hash partitioning.

To satisfy both zero-tolerance financial data integrity and high-velocity semi-structured
operational needs, CedarPay adopts a hybrid Polyglot Persistence architecture:

A. Relational Financial Core (PostgreSQL 18 / PostgreSQL 16 Docker):
   - System of record for all money movements, customer accounts, and audit ledgers.
   - Core tables: `customers`, `kyc_records`, `accounts`, `beneficiaries`, `cards`,
     `transactions`, `ledger_entries`, and `fraud_flags`.
   - Immutable double-entry financial ledger: Every financial transaction creates balanced
     DEBIT and CREDIT ledger entries enforcing the fundamental accounting identity.
   - Rigorous domain integrity: NUBAN 10-digit regex constraints, non-negative cached balances,
     idempotency keys preventing double-spending and network replay attacks, and strict
     foreign key references with ON DELETE RESTRICT.
   - Concurrency & ACID Guarantees: Custom PL/pgSQL transfer function using deterministic
     account ordering (`ORDER BY account_id ASC`) with exclusive row-level locking
     (`FOR UPDATE`) to mathematically eliminate deadlock hazards during concurrent transfers.
   - Scale & High Availability: Physical WAL streaming replication with synchronous/asynchronous
     failover capabilities and declarative 4-way hash partitioning on `ledger_entries`.

B. Document Store Operational Core (MongoDB & MongoDB Atlas):
   - System of engagement for flexible, polystructured customer data.
   - Collections: `kyc_profiles`, `audit_events`, and `login_sessions`.
   - Native `$jsonSchema` validation rejecting non-compliant documents (Error Code 121).
   - TTL indexes automatically expiring ephemeral login session tokens after 30 days.
   - High-throughput aggregation pipelines for fraud velocity analysis, KYC verification
     funnels, and regional transaction density reporting.
   - Managed multi-node cloud availability: 3-member MongoDB Atlas replica set in AWS Paris
     demonstrating majority write durability and secondary read consistency.

================================================================================
2. SUBMISSION FILE MANIFEST & 40-MARK RUBRIC MAPPING
================================================================================
The submitted package conforms strictly to the `Surname_Firstname_DocumentType`
naming standard with zero spaces. Every file is mapped below to its evaluation component:

--------------------------------------------------------------------------------
A. FINAL SYNTHESIS & GOVERNANCE DOCUMENTATION
--------------------------------------------------------------------------------
1. Chirim_Amarachukwu_README.txt
   - Standalone catalog, table of contents, execution guide, and metadata.
   - Rubric Component: Documentation & Organisation (5 Marks).

2. Chirim_Amarachukwu_Final_Report.pdf (and .md)
   - 2-to-3 page executive synthesis covering case study architecture, summaries of
     Portfolios 1–5, technical reflection, and AI declaration.
   - Rubric Component: Technical Reflection & Synthesis (3 Marks).

3. Chirim_Amarachukwu_AI_Use_Declaration.md
   - Formal disclosure of AI tools (ChatGPT/Claude) used for ideation, troubleshooting,
     and drafting, confirming independent execution of code and evidence.
   - Rubric Component: Technical Reflection & Academic Integrity (3 Marks).

4. Chirim_Amarachukwu_References.md
   - Academic and industry citations (PostgreSQL docs, MongoDB manuals, CBN guidelines).
   - Rubric Component: Documentation & Standards (5 Marks).

--------------------------------------------------------------------------------
B. PORTFOLIO 1: RELATIONAL DATABASE DESIGN & MODELLING (14 Marks: Design 6 + Technical 8)
--------------------------------------------------------------------------------
1. Chirim_Amarachukwu_P1_CaseStudy.md
   - Comprehensive Nigerian fintech business context, compliance rules, actor personas.
2. Chirim_Amarachukwu_P1_RelationalSchema.md
   - Full schema specification, DDL rationale, and data dictionary.
3. Chirim_Amarachukwu_P1_Normalisation.md
   - Exhaustive 1NF, 2NF, 3NF, and BCNF normalization proofs and controlled denormalization.
4. Chirim_Amarachukwu_P1_CreateSchema.sql
   - Complete PostgreSQL 18 DDL script creating all 8 tables, sequences, checks, and foreign keys.
5. Chirim_Amarachukwu_P1_SeedData.sql
   - Deterministic seed script populating 5,001 customers, 6,001 accounts, and baseline records.
6. Chirim_Amarachukwu_P1_ConstraintTests.sql
   - 640+ lines of positive and negative test cases validating domain constraints and check rules.
7. Chirim_Amarachukwu_ERD.png & Chirim_Amarachukwu_ERD.drawio
   - High-resolution Entity Relationship Diagram and vector source model.
8. Evidence Screenshots (P1 Evidence):
   - Chirim_Amarachukwu_P1_Evidence_DB_Setup.png
   - Chirim_Amarachukwu_P1_Evidence_Tables.png
   - Chirim_Amarachukwu_P1_Evidence_Constraints.png
   - Chirim_Amarachukwu_P1_Evidence_Seed_Verification.png

--------------------------------------------------------------------------------
C. PORTFOLIO 2: QUERY PROCESSING & OPTIMISATION (5 Marks: Query & Performance Analysis)
--------------------------------------------------------------------------------
1. Chirim_Amarachukwu_P2_README.md
   - Workload profile and benchmark environment setup guide.
2. Chirim_Amarachukwu_P2_PerformanceResults.md
   - Comprehensive benchmark report across 11 queries analyzing execution plans, buffer hits,
     cost models, speedup ratios (up to 3.48x), and write-cost overheads.
3. Chirim_Amarachukwu_P2_Queries.sql
   - Consolidated SQL suite containing Queries Q01 through Q11.
4. Chirim_Amarachukwu_P2_CreateIndexes.sql
   - DDL for composite, partial, and covering B-Tree indexes.
5. Chirim_Amarachukwu_P2_DropIndexes.sql & Chirim_Amarachukwu_P2_PlannerExperiments.sql
   - Scripts for testing index drops, cost parameter tuning, and planner behaviors.
6. Evidence Screenshots (P2 Evidence):
   - Graphical execution plans and EXPLAIN ANALYZE comparison outputs for Q01 to Q11.

--------------------------------------------------------------------------------
D. PORTFOLIO 3: TRANSACTIONS & CONCURRENCY CONTROL (13 Marks: Advanced 5 + Practical 8)
--------------------------------------------------------------------------------
1. Chirim_Amarachukwu_P3_README.md
   - ACID guarantee analysis, isolation level mechanics, and locking protocols.
2. Chirim_Amarachukwu_P3_ConcurrencyAnalysis.md
   - In-depth evaluation of non-repeatable reads, deadlocks, and lock order prevention.
3. Chirim_Amarachukwu_P3_TransactionScripts.sql
   - PL/pgSQL transfer function (`transfer_funds`), flawed transfer function for deadlock demo,
     and multi-session isolation test scripts.
4. Chirim_Amarachukwu_P3_StressTest.sh
   - Automated concurrent transfer test harness verifying deadlock-free parallel execution.
5. Evidence Screenshots (P3 Evidence):
   - Chirim_Amarachukwu_P3_Evidence_Commit_Pending.png
   - Chirim_Amarachukwu_P3_Evidence_Commit_Committed.png
   - Chirim_Amarachukwu_P3_Evidence_Rollback_Restored.png
   - Chirim_Amarachukwu_P3_Evidence_Read_Committed_Anomalies.png
   - Chirim_Amarachukwu_P3_Evidence_Repeatable_Read_Snapshot.png
   - Chirim_Amarachukwu_P3_Evidence_Deadlock_Detected.png
   - Chirim_Amarachukwu_P3_Evidence_Ordered_Lock_Resolved.png

--------------------------------------------------------------------------------
E. PORTFOLIO 4: NOSQL & ADVANCED DATA MODELS (13 Marks: Advanced 5 + Practical 8)
--------------------------------------------------------------------------------
1. Chirim_Amarachukwu_P4_README.md
   - Document data store design, collection architectures, and validation guidelines.
2. Chirim_Amarachukwu_P4_NoSQLModelDesign.md
   - Document modeling paradigms (embedding vs referencing) for KYC, audit events, and sessions.
3. Chirim_Amarachukwu_P4_SQLvsNoSQLRationale.md
   - Architectural comparison between relational ACID guarantees and NoSQL document flexibility.
4. Chirim_Amarachukwu_P4_Scripts.js
   - Consolidated MongoDB JavaScript suite covering `$jsonSchema` validators, 105,000 document
     seed script, CRUD operations, 5 aggregation pipelines, and index execution stats.
5. Evidence Screenshots (P4 Evidence):
   - Chirim_Amarachukwu_P4_Evidence_Schema_Validation_Error121.png
   - Chirim_Amarachukwu_P4_Evidence_Seed_Verification.png
   - Chirim_Amarachukwu_P4_Evidence_Aggregation_Outputs.png
   - Chirim_Amarachukwu_P4_Evidence_Index_Scans_COLLSCAN_vs_IXSCAN.png
   - Chirim_Amarachukwu_P4_Evidence_Compass_Document_Views.png

--------------------------------------------------------------------------------
F. PORTFOLIO 5: DISTRIBUTED & CLOUD DATABASES (13 Marks: Advanced 5 + Practical 8)
--------------------------------------------------------------------------------
1. Chirim_Amarachukwu_P5_README.md
   - Architecture guide for Dockerized PostgreSQL replication and MongoDB Atlas cloud cluster.
2. Chirim_Amarachukwu_P5_ReplicationAndFailover.md
   - Physical streaming replication, lag simulation, synchronous write waits, and failover via `pg_promote()`.
3. Chirim_Amarachukwu_P5_ShardingPartitioning.md
   - PostgreSQL declarative hash partitioning analysis and partition pruning benchmarks.
4. Chirim_Amarachukwu_P5_AvailabilityAndRecovery.md
   - CAP theorem / PACELC trade-offs, RTO/RPO analysis, and high-availability architecture.
5. Chirim_Amarachukwu_P5_Scripts.sh
   - Automated environment runner orchestrating Docker replication and healthchecks.
6. Evidence Screenshots (P5 Evidence):
   - Chirim_Amarachukwu_P5_Evidence_Docker_Primary_Replica.png
   - Chirim_Amarachukwu_P5_Evidence_Replication_Lag_Stale_Read.png
   - Chirim_Amarachukwu_P5_Evidence_Sync_Replication_Hang.png
   - Chirim_Amarachukwu_P5_Evidence_Standby_Promotion_Failover.png
   - Chirim_Amarachukwu_P5_Evidence_Partition_Pruning_Plan.png
   - Chirim_Amarachukwu_P5_Evidence_Atlas_Cluster_Metrics.png
   - Chirim_Amarachukwu_P5_Evidence_Read_Consistency_Comparison.png

================================================================================
3. STEP-BY-STEP REPRODUCTION & VERIFICATION GUIDE FOR ASSESSORS
================================================================================

PREREQUISITES:
- PostgreSQL 16 or 18 (psql and pgAdmin 4).
- Docker and Docker Compose (v2.20+ recommended).
- MongoDB Community Server (v7.0+) or mongosh shell (v2.0+).
- Node.js (v18+) optional for extended verification.

--------------------------------------------------------------------------------
STEP 1: VERIFY PORTFOLIO 1 (RELATIONAL SCHEMA & CONSTRAINTS)
--------------------------------------------------------------------------------
1. Open terminal and connect to your local PostgreSQL instance:
   psql -U postgres
2. Create and connect to the target database:
   CREATE DATABASE cedarpay_db;
   \c cedarpay_db
3. Execute the schema generation script:
   \i Chirim_Amarachukwu_P1_CreateSchema.sql
4. Populate baseline and seed entities:
   \i Chirim_Amarachukwu_P1_SeedData.sql
5. Run the constraint validation suite (verifies CHECK rules and foreign keys):
   \i Chirim_Amarachukwu_P1_ConstraintTests.sql
   (All expected error codes such as 23514 check_violation and 23505 unique_violation will trigger as designed).

--------------------------------------------------------------------------------
STEP 2: VERIFY PORTFOLIO 2 (QUERY OPTIMISATION & INDEXING)
--------------------------------------------------------------------------------
1. Connect to `cedarpay_db`:
   psql -U postgres -d cedarpay_db
2. Verify baseline execution plans without custom indexes:
   \i Chirim_Amarachukwu_P2_Queries.sql
3. Deploy the optimized index suite:
   \i Chirim_Amarachukwu_P2_CreateIndexes.sql
4. Rerun queries with EXPLAIN (ANALYZE, BUFFERS) to observe index scans and latency reductions:
   EXPLAIN (ANALYZE, BUFFERS) SELECT ... (from Chirim_Amarachukwu_P2_Queries.sql)
5. Review performance findings against Chirim_Amarachukwu_P2_PerformanceResults.md.

--------------------------------------------------------------------------------
STEP 3: VERIFY PORTFOLIO 3 (TRANSACTIONS & CONCURRENCY CONTROL)
--------------------------------------------------------------------------------
1. Connect to `cedarpay_db`:
   psql -U postgres -d cedarpay_db
2. Deploy transfer functions and test fixtures:
   \i Chirim_Amarachukwu_P3_TransactionScripts.sql
3. Test atomic transfer:
   SELECT transfer_funds(9000000001, 9000000002, 25.0000, 'IDEMP-TEST-001');
   Verify updated balances and balanced double-entry ledger rows:
   SELECT account_number, balance FROM accounts WHERE account_id IN (9000000001, 9000000002);
   SELECT * FROM ledger_entries WHERE transaction_id = (SELECT transaction_id FROM transactions WHERE idempotency_key = 'IDEMP-TEST-001');
4. Run the automated stress test harness to verify deadlock resilience:
   chmod +x Chirim_Amarachukwu_P3_StressTest.sh
   ./Chirim_Amarachukwu_P3_StressTest.sh

--------------------------------------------------------------------------------
STEP 4: VERIFY PORTFOLIO 4 (MONGODB NOSQL MODEL & AGGREGATIONS)
--------------------------------------------------------------------------------
1. Launch MongoDB local daemon and connect via `mongosh`:
   mongosh "mongodb://localhost:27017/CedarPay_db"
2. Execute validation rules, sample data insertion, and queries:
   load("Chirim_Amarachukwu_P4_Scripts.js");
3. Observe output:
   - Schema validation rejection on invalid KYC document (code 121).
   - Summary counts of 5,000 KYC profiles and 100,000 audit events.
   - Aggregation outputs showing top login cities and transaction funnels.
   - Execution stats demonstrating transition from COLLSCAN to IXSCAN.

--------------------------------------------------------------------------------
STEP 5: VERIFY PORTFOLIO 5 (DISTRIBUTED REPLICATION, FAILOVER & PARTITIONING)
--------------------------------------------------------------------------------
1. Navigate to the distributed environment directory:
   cd portfolio-5-distributed-cloud
2. Launch Docker Compose primary and replica containers:
   docker compose up -d
3. Check container health and replication status:
   docker exec -it cedar_postgres_primary psql -U cedar_admin -d cedarpay_db -c "SELECT client_addr, state, sync_state FROM pg_stat_replication;"
4. Verify replica read-only enforcement:
   docker exec -it cedar_postgres_replica psql -U cedar_admin -d cedarpay_db -c "SELECT pg_is_in_recovery();"
   docker exec -it cedar_postgres_replica psql -U cedar_admin -d cedarpay_db -c "INSERT INTO customers (first_name, last_name, email, phone, customer_type) VALUES ('Test', 'User', 'fail@test.com', '08000000000', 'INDIVIDUAL');"
   (Returns: ERROR: cannot execute INSERT in a read-only transaction).
5. Test partition pruning:
   docker exec -it cedar_postgres_primary psql -U cedar_admin -d cedarpay_db -f /Chirim_Amarachukwu_P5_ShardingPartitioning.sql
   Observe EXPLAIN plans showing single-partition scan on `account_id` queries versus 4-partition scan when unconstrained.

================================================================================
4. ACADEMIC INTEGRITY & AI-USE DECLARATION
================================================================================
In accordance with Miva Open University postgraduate academic regulations:
I hereby declare that this practical database portfolio is the original work of
Chirim Amarachukwu (Student ID: 301914084). Generative AI assistance (OpenAI ChatGPT /
Anthropic Claude) was utilized for conceptual explanations, script debugging, syntax
verification, and drafting assistance. All database instances, containerized clusters,
DDL scripts, benchmarking queries, failover routines, and empirical screenshot evidence
were personally executed, captured, and validated on my development systems.

Signed:     Chirim Amarachukwu
Date:       November 2026
Course:     MIT 8103: Advanced Database Systems
Institution: Miva Open University — School of Post Graduate Studies
================================================================================


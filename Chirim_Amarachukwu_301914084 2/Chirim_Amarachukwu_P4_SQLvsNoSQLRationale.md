# Portfolio 4: Architectural Rationale — SQL vs. NoSQL (CedarPay)

**Course:** MIT 8103 Advanced Database Systems  
**Student Name:** Chirim Amarachukwu  
**Student ID:** 301914084  

---

## 1. The Polyglot Persistence Architecture
Fintech platforms cannot afford a dogmatic single-database approach. Financial ledgers and identity documents possess fundamentally irreconcilable data models:

| Architectural Dimension | PostgreSQL 18 (Relational Core) | MongoDB (Document Operational Store) |
| :--- | :--- | :--- |
| **Primary Responsibility** | Accounts, Balances, Transfers, Double-Entry Ledger | KYC Submissions, Audit Trails, Active Sessions |
| **Data Structure** | Rigid tabular relations with strict DDL | Flexible, polymorphic JSON/BSON documents |
| **Consistency Paradigm** | Immediate ACID consistency; serializable transactions | Tunable consistency; single-document ACID; eventual read |
| **Integrity Enforcement** | Engine-level foreign keys, check constraints, triggers | Native `$jsonSchema` validation (Error 121) |
| **Query Mechanism** | Declarative SQL, joins, recursive CTEs, window functions | MQL (MongoDB Query Language), Aggregation Pipelines |
| **Scaling Model** | Vertical scaling, physical read replicas, table partitioning | Horizontal auto-sharding, replica sets |

## 2. Managing the Dual-Database Boundary
Because cross-database foreign keys do not exist between PostgreSQL and MongoDB:
1. **Shared Key Contract:** `customer_id` serves as the logical correlation identifier across both systems.
2. **Application Middleware:** Application services must verify customer existence in PostgreSQL before inserting KYC profiles into MongoDB.
3. **Reconciliation Audits:** Scheduled asynchronous jobs sweep both datastores to flag orphan audit logs or missing KYC records, preserving holistic system integrity.

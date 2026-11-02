# Portfolio 5: High Availability, Recovery & Cloud Resilience — CedarPay

**Course:** MIT 8103 Advanced Database Systems  
**Student Name:** Chirim Amarachukwu  
**Student ID:** 301914084  

---

## 1. High Availability Architecture & RTO / RPO Metrics
In enterprise fintech engineering, disaster recovery is quantified through two metrics:
- **Recovery Point Objective (RPO):** Maximum acceptable data loss duration.
- **Recovery Time Objective (RTO):** Maximum allowable downtime before service restoration.

| System Component | Deployment Model | Failover Mechanism | RPO Target | RTO Target |
| :--- | :--- | :--- | :--- | :--- |
| **PostgreSQL Financial Ledger** | 2-Node Docker Physical Streaming Replication | Manual promotion via `pg_promote()` (or Patroni / PgBouncer in production) | RPO $\approx 0$ (Sync) / $< 1$s (Async) | RTO $< 30$ seconds |
| **MongoDB Operational Store** | 3-Node Managed Replica Set (MongoDB Atlas M0, AWS Paris) | Automated consensus election using Raft-variant protocol | RPO = 0 (Majority write concern) | RTO $< 5$ seconds (Automatic leader election) |

## 2. CAP & PACELC Theorem Trade-Offs in Practice
Under Eric Brewer's CAP Theorem and Daniel Abadi's PACELC formulation:
- **Relational Financial Ledger (PC/EC):** Prioritizes Consistency over Availability during network partitions. Under synchronous replication, if a partition isolates the standby node, the primary rejects write commits rather than risk split-brain inconsistency or divergent financial ledgers.
- **Operational Audit Store (PA/EL):** In MongoDB Atlas, high availability and low latency are prioritized. Read operations using `readPreference: "secondaryPreferred"` allow the application to continue serving read traffic even if network jitter temporarily increases replication lag.

## 3. Cloud Replica Set Verification in MongoDB Atlas
- **Topology:** Primary + 2 Secondaries running across distinct AWS availability zones.
- **Durability Guarantee:** Writes executed with `w: "majority"` acknowledge commits only after persistent replication across a quorum of nodes.
- **Consistency Verification:** Multi-sample read queries comparing customer login counts between the primary node and secondary nodes yielded identical counts, verifying causal consistency.

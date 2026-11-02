# Portfolio 5: Replication and Failover Analysis — CedarPay

**Course:** MIT 8103 Advanced Database Systems  
**Student Name:** Chirim Amarachukwu  
**Student ID:** 301914084  

---

## 1. Physical Streaming Replication Architecture
CedarPay implements PostgreSQL physical streaming replication using Write-Ahead Logging (WAL) shipping:
- **Primary Node:** `cedar_postgres_primary` (Docker container on port 5433).
- **Standby Node:** `cedar_postgres_replica` (Docker container on port 5434).
- **Transport Mechanism:** Continuous physical streaming over TCP via PostgreSQL WAL sender processes (`wal_level = replica`, `max_wal_senders = 10`).

## 2. Replication Lag & Stale Read Demonstration
1. **Normal Flow:** Transactions committed on the primary write WAL records, which are immediately shipped to the replica and replayed into the database buffers.
2. **Lag Injection:** Calling `SELECT pg_wal_replay_pause();` on the replica suspends WAL application while keeping network streaming active.
3. **Stale Read Observation:** A canary record inserted on the primary was immediately visible on the primary (`SELECT count(*) = 1`), but absent on the standby replica (`count(*) = 0`), empirically proving the risk of stale reads in read-replica architectures.
4. **Recovery & Catch-Up:** Calling `SELECT pg_wal_replay_resume();` allowed the replica to catch up, restoring byte parity between primary LSN and replica replay LSN.

## 3. Synchronous Replication & Durability Trade-Offs
- With `synchronous_commit = on` and `synchronous_standby_names = 'FIRST 1 (replica_node)'`, the primary guarantees that no commit is acknowledged until the WAL is flushed on the standby.
- When the standby container was intentionally terminated, subsequent client write transactions hung indefinitely in wait states. Client cancellation confirmed that the transaction committed locally on the primary's WAL but could not be guaranteed across the cluster, exposing the availability penalty of strict consistency.

## 4. Unplanned Failover & Manual Promotion
- Upon shutting down the primary node, the standby replica was promoted to primary status via:
  ```sql
  SELECT pg_promote();
  ```
- Verification confirmed that `pg_is_in_recovery()` switched from `true` to `false`, allowing the standby to transition out of read-only mode and successfully accept write transactions.


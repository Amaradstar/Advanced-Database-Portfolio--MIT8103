# MIT 8103 Portfolio 5: Distributed and Cloud Databases

**Student:** Chirim Amarachukwu  
**Student ID:** 301914084  
**Case study:** CedarPay

## Objective

This portfolio explores PostgreSQL streaming replication, replication lag, synchronous replication, failover, hash partitioning, and a managed MongoDB Atlas replica set.

## Architecture

- PostgreSQL 16 runs in Docker as a primary and a streaming read replica. The primary is exposed on port `5433` and the replica on `5434`.
- The CedarPay PostgreSQL dataset was restored to the primary and replicated to the standby.
- A partitioned copy of `ledger_entries` uses PostgreSQL hash partitioning on `account_id`, with four partitions. This demonstrates partition pruning on one PostgreSQL server; it is not a multi-server sharded deployment.
- MongoDB Atlas hosts the CedarPay NoSQL data in `CedarPay_db`. The Atlas cluster has three replica-set members in the AWS Paris region.

## Experiments and results

### PostgreSQL replication

The replica reported that it was in recovery, streamed WAL from the primary, returned the restored CedarPay table counts, and rejected writes as read-only.

Pausing WAL replay demonstrated a stale read: the primary showed a new marker before the replica did. Resuming replay allowed the replica to catch up.

With synchronous replication enabled, writes succeeded while the replica was available. When the replica was stopped, a write waited for synchronous confirmation. The client cancellation warned that the write had committed locally but might not have reached the standby. Synchronous settings were reset afterward.

The replica was then manually promoted. It left recovery mode and accepted a new write. This demonstrates manual failover, not automatic failover.

### PostgreSQL partitioning

The partitioned ledger copy contained the same 404,164 rows as the original table, distributed across four hash partitions. `EXPLAIN` showed a query filtered by `account_id` scanning one partition; a query without the partition key scanned all four.

### MongoDB Atlas

Atlas reported three replica-set members and identified a primary. The cloud check acknowledged a majority write, read the marker using secondary read preference and majority read concern, then deleted the temporary marker.

The additional read consistency experiment counted successful login events using primary and secondary read preferences. The counts matched.

## Design reflection

PostgreSQL is a good fit for CedarPay’s financial records because transactions, constraints, and a clear source of truth matter for balances and ledger entries. Streaming replication provides a read-only copy for read workloads, but asynchronous replication can leave that copy briefly behind the primary. The pause and catch-up experiment made that trade-off visible. Synchronous replication reduces the chance of acknowledging a write before a standby receives it, but it can delay writes or block them when the standby is unavailable.

Hash partitioning keeps an account’s ledger entries together and lets PostgreSQL prune partitions when a query includes `account_id`. The experiment also showed why choosing a useful partition key matters: queries without that key still need to scan all partitions. This partitioned table is a single-server model, not a true distributed shard setup.

MongoDB Atlas manages the three-member replica set and supports majority writes and secondary reads. The primary and secondary count comparison showed that both could return the same majority-committed result for this workload. Together, the exercises show how replication and partitioning help with availability and data access, while introducing trade-offs around freshness, write availability, and query design.

## Reproducibility and evidence

The SQL files, MongoDB check scripts, command outputs, and numbered screenshots are included in this portfolio folder. The PostgreSQL dump file is not committed; create or obtain the CedarPay dump separately before restoring the database and rerunning the PostgreSQL exercises.

## AI use

ChatGPT was used for step-by-step guidance, code explanations, and README drafting. I ran the commands, reviewed the outputs, and captured the evidence included in this portfolio.
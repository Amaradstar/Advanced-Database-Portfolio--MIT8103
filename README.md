# Advanced Database Systems Portfolio — MIT 8103

**Student:** Chirim Amarachukwu  
**Student ID:** 301914084  
**Case study:** CedarPay, a simulated Nigerian fintech platform  
**Course:** Advanced Database Systems (MIT 8103)

This repository contains five progressive database portfolios that design, query, secure, and distribute CedarPay data. Each portfolio folder contains its own README, implementation files, and supporting evidence.

## Portfolio guide

| Portfolio | Focus | Details |
|---|---|---|
| [Portfolio 1: Relational database design](portfolio-1-database-design/README.md) | PostgreSQL schema design, normalization, integrity constraints, and double-entry ledger foundations. | [Open folder](portfolio-1-database-design/) |
| [Portfolio 2: Query processing and optimization](portfolio-2-query-optimisation/README.md) | Query plans, index design, workload analysis, and performance trade-offs in PostgreSQL. | [Open folder](portfolio-2-query-optimisation/) |
| [Portfolio 3: Transactions and concurrency](portfolio-3-transactions-concurrency/README.md) | COMMIT and ROLLBACK, isolation levels, concurrent access, deadlocks, and controls. | [Open folder](portfolio-3-transactions-concurrency/) |
| [Portfolio 4: NoSQL with MongoDB](portfolio-4-nosql/README.md) | MongoDB document validation, CRUD, aggregation, indexes, and query-plan evidence. | [Open folder](portfolio-4-nosql/) |
| [Portfolio 5: Distributed and cloud databases](portfolio-5-distributed-cloud/README.md) | PostgreSQL streaming replication, lag, synchronous replication, manual failover, hash partitioning, and MongoDB Atlas replica-set checks. | [Open folder](portfolio-5-distributed-cloud/) |

## CedarPay data architecture

PostgreSQL is used for structured financial records such as customers, accounts, transactions, and ledger entries. Its constraints and transaction support help maintain financial integrity. MongoDB is used for flexible KYC profiles, audit events, and login sessions. Application-level checks are needed when references such as customer_id span both databases.

Portfolio 5 adds a PostgreSQL primary and read replica for replication exercises, a four-partition hash-partitioned ledger copy, and a three-member MongoDB Atlas replica set. The partitioning exercise uses one PostgreSQL server to demonstrate partition pruning; it is not presented as a multi-server shard deployment.

## Repository layout

Each portfolio directory contains its own scripts, documentation, and evidence. Screenshots and command outputs are stored in the relevant portfolio folders. Start with the README inside each folder for its requirements, execution order, and results.

The PostgreSQL dump used in Portfolio 5 is intentionally excluded from version control. Create or obtain that dump separately before repeating the restore exercise. Do not commit database credentials, .env files, or connection strings.

## Tools

- PostgreSQL 18 and pgAdmin 4 for relational design, query analysis, and transaction work.
- PostgreSQL 16 in Docker Compose for the Portfolio 5 replication and failover lab.
- MongoDB Compass and mongosh for local MongoDB work.
- MongoDB Atlas for the Portfolio 5 cloud replica-set exercise.
- Git and GitHub for version control and progressive portfolio commits.

## AI-use declaration

AI assistance was used for explanations, troubleshooting, code guidance, and drafting. I ran the database commands, reviewed the outputs, and captured the submitted evidence.

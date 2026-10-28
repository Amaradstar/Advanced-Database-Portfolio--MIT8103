# Portfolio 4: CedarPay NoSQL with MongoDB

## Purpose

This portfolio demonstrates how CedarPay uses MongoDB to store and work with flexible KYC profile documents and customer audit events. PostgreSQL remains responsible for CedarPay's financial records, such as account balances and transfers. The portfolio covers schema validation, sample data, CRUD operations, aggregation pipelines, and indexes.

## Data model

The `CedarPay_db` MongoDB database contains three portfolio collections:

- `kyc_profiles` stores each customer's KYC tier, verification status, identity documents, and any risk notes. Documents can have different numbers and types of identity records, so this information fits MongoDB's flexible document structure.
- `audit_events` stores customer activity such as successful or failed logins, transfers, PIN changes, and KYC updates. Each event includes a timestamp and event-specific details.
- `login_sessions` stores session tokens and creation times. A TTL index removes expired session records.

The KYC and audit collections use `customer_id` to associate their documents with a customer. MongoDB does not enforce a foreign key to the PostgreSQL customer record, so the application must validate customer IDs and periodically check for missing or unmatched references. PostgreSQL remains the source of truth for account balances and transfers.

## Schema validation

MongoDB collection validators check that inserted documents have the required fields and valid values. The portfolio tests an invalid KYC document and confirms MongoDB rejects it with validation error code `121`.

The validation script is [`01_schema_validation.js`](./01_schema_validation.js). A screenshot of the rejection result is saved in the `screenshots` folder.

## Sample data

The seed script creates 5,000 KYC profiles and 100,000 audit events in `CedarPay_db`. The profiles include different KYC tiers and document types, while audit events represent customer activity.

The script verifies the inserted totals and prints event counts by type. Its output is saved in [`output/02_seed_verification.txt`](./output/02_seed_verification.txt). The script is [`02_seed_data.js`](./02_seed_data.js).

## CRUD operations

The CRUD script demonstrates creating a temporary KYC profile, reading profiles and audit events, updating a profile, and deleting the temporary profile and its test audit event. It also checks for tier 3 customers with passports and passports expiring within the next 365 days.

The script is [`03_crud_and_aggregation.js`](./03_crud_and_aggregation.js). Its output is saved in [`output/03_crud_and_aggregation.txt`](./output/03_crud_and_aggregation.txt).

## Aggregation pipelines

The CRUD script also runs four aggregation pipelines:

1. Counts audit events by type over the last 30 days.
2. Calculates transfer counts and amounts by day.
3. Finds customers with the most failed logins and shows their KYC details.
4. Calculates the average number of identity documents for each KYC tier.

My additional pipeline in [`05_own_aggregation.js`](./05_own_aggregation.js) finds the five cities with the most successful logins in the last 30 days. It reports login counts and distinct customers. Its output is saved in [`output/05_own_aggregation.txt`](./output/05_own_aggregation.txt).

In these pipelines, `$match` filters documents, `$group` combines matching documents by a key and calculates results, and `$sort` orders those results.

## Indexes and query performance

Before indexing, the three example queries used collection scans. After creating indexes, MongoDB used index scans:

| Query | Before | After |
|---|---:|---:|
| Latest events for customer 1001 | 100,000 documents examined; 225 ms | 16 documents examined; 5 ms |
| FRAUD_FLAG events from the last 7 days | 100,000 documents examined; 25 ms | 363 documents examined; 2 ms |
| KYC profile for customer 2500 | 5,000 documents examined; 13 ms | 1 document examined; 2 ms |

The indexes improved these measured queries by reducing the documents examined. The unique index also rejected a duplicate `customer_id`. The TTL index was used to expire old login sessions. Indexes take storage space as well as helping reads; for example, the audit-event indexes used 3.3 MB in this run.

The script is [`04_indexes_explain.js`](./04_indexes_explain.js). Its output is saved in [`output/04_indexes_explain.txt`](./output/04_indexes_explain.txt).

## Reflection

I found MongoDB Compass interactive for exploring documents. I needed to install the standalone `mongosh` shell to run my saved scripts because Compass’s embedded shell could not load them. pgAdmin felt more technical, but its Query Tool let me run multiple SQL statements. I enjoyed using both because they showed me that CedarPay has different kinds of data: PostgreSQL is a good fit for balances and transfers that need reliable transactions, while MongoDB works well for flexible KYC profiles and growing audit events. PostgreSQL felt faster in the queries I ran, but I did not compare the same workload in both systems, so I cannot conclude that it is generally faster. The MongoDB `explain()` results showed how indexing helped: one query examined 100,000 documents before indexing and 16 afterward. If I repeated the work, I would compare the same query and data volume in both systems for a fairer performance comparison.

## Reproducing the work

Run these scripts from the repository’s `portfolio-4-nosql` directory using `mongosh` connected to `CedarPay_db`:

1. `01_schema_validation.js` — create the validated collections and test rejection of an invalid KYC document.
2. `02_seed_data.js` — seed 5,000 KYC profiles and 100,000 audit events.
3. `03_crud_and_aggregation.js` — run CRUD examples and aggregation pipelines.
4. `04_indexes_explain.js` — create indexes and compare query plans.
5. `05_own_aggregation.js` — run the additional successful-login city analysis.

The seed script clears and repopulates its portfolio collections. Run it only when you intend to reset that sample data.

## AI-use declaration

I used AI assistance(claude and chatgpt) to help plan the portfolio, understand MongoDB concepts, troubleshoot commands, and draft parts of this README. I ran the database scripts and reviewed the outputs myself.

## Evidence

Screenshots of the schema validation, seeded data, CRUD operations, aggregation results, index comparisons, TTL behavior, and MongoDB Compass are stored in the [`screenshots`](./screenshots/) folder. Command outputs are stored in the [`output`](./output/) folder.

## PostgreSQL and MongoDB comparison

PostgreSQL stores CedarPay’s financial records, including account balances and transfers. Its relational tables, constraints, and transactions help keep those records consistent when a transfer updates more than one account. PostgreSQL also supports joins and structured queries across related tables.

MongoDB stores KYC profiles, audit events, and login sessions in documents. The document structure accommodates profiles with different numbers and types of identity documents, while audit-event details can vary by event type. MongoDB aggregation pipelines support analysis of this activity, and indexes improved the query plans in this portfolio.

The databases do not automatically enforce a relationship between a MongoDB `customer_id` and a PostgreSQL customer record. An application should check that referenced customers exist and periodically reconcile IDs across both databases. Keeping balances and transfers in PostgreSQL and flexible profile and event data in MongoDB lets CedarPay use each database for the data it handles well, while requiring the application to maintain consistency between them.
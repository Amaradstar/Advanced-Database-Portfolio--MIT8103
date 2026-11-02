# Portfolio 3: Transactions and Concurrency

**Course:** Advanced Database Systems (MIT 8103)  
**Student:** Chirim Amarachukwu (301914084)  
**Case study:** CedarPay, a simulated Nigerian fintech platform  
**Database:** PostgreSQL 18, managed through pgAdmin 4

## Objective

This portfolio demonstrates how database transactions and row-level locking protect account updates in a CedarPay fund-transfer scenario. It covers explicit COMMIT and ROLLBACK, transaction isolation, a deadlock caused by inconsistent lock order, and the use of a consistent lock order to control that concurrency problem.

## Files

| File | Purpose |
|---|---|
| [`01_transfer_function.sql`](sql/01_transfer_function.sql) | Defines `transfer_funds`, which validates transfers, locks accounts by ascending `account_id`, updates balances, and writes debit and credit ledger entries. It also defines `transfer_funds_unordered` for studying the risk of opposite lock order. |
| [`02_demo_setup.sql`](sql/02_demo_setup.sql) | Creates or resets the Alice and Bob demo accounts to 500.0000. |
| [`03_commit_rollback_demo.sql`](sql/03_commit_rollback_demo.sql) | Demonstrates a committed transfer and a separate rolled-back change. |
| [`04_isolation_demo.sql`](sql/04_isolation_demo.sql) | Provides the two-session READ COMMITTED and REPEATABLE READ demonstrations. |
| [`05_concurrency_demo.sql`](sql/05_concurrency_demo.sql) | Provides the two-session deadlock and ordered-lock demonstrations. |

## Prerequisites and setup

The `CedarPay_db` database must already contain the tables used by the transfer scripts, including `customers`, `accounts`, `transactions`, and `ledger_entries`. Create the database schema using the earlier portfolio setup before running these scripts.

Connect to `CedarPay_db` in pgAdmin 4. Run [`02_demo_setup.sql`](sql/02_demo_setup.sql) to prepare two dedicated demo accounts:

- Alice: `9000000001`
- Bob: `9000000002`
- Starting balance: `500.0000` each

The setup script resets these two demo accounts only. Run [`01_transfer_function.sql`](sql/01_transfer_function.sql) to create the transfer functions.

## Demonstrations

### COMMIT and ROLLBACK

Run [`03_commit_rollback_demo.sql`](sql/03_commit_rollback_demo.sql) after resetting the demo accounts with `02_demo_setup.sql`.

The COMMIT example transfers 25 from Alice to Bob. The balances change from 500.0000 each to 475.0000 and 525.0000, and remain changed after COMMIT.

The ROLLBACK example reduces Alice’s balance by 10 inside a transaction. The temporary balance is 490.0000; after ROLLBACK, both demo balances are 500.0000.

### Transaction isolation

The examples in [`04_isolation_demo.sql`](sql/04_isolation_demo.sql) require two pgAdmin Query Tool sessions. Run each statement separately in the labeled session; don’t execute the whole file as a single script. Reset the demo accounts with `02_demo_setup.sql` before each isolation-level demonstration.

Under READ COMMITTED, Session A first reads Alice’s balance as 500.0000. Session B commits an increase of 1. Session A’s next read sees 501.0000.

Under REPEATABLE READ, Session A first reads 500.0000. Session B commits the same increase of 1, but Session A’s next read remains 500.0000 for the duration of its transaction.

### Deadlock and ordered-lock control

The examples in [`05_concurrency_demo.sql`](sql/05_concurrency_demo.sql) also require two Query Tool sessions. Run the statements separately in the labeled session.

The deadlock demonstration has Session A lock Alice and then request Bob, while Session B locks Bob and then requests Alice. PostgreSQL detects the circular wait and cancels one request.

For the control demonstration, both sessions request the accounts in ascending `account_id` order. Session B waits for Session A’s first lock, then proceeds after Session A commits. The account IDs were checked for this demo, and Alice’s ID was lower than Bob’s.

The safe `transfer_funds` function in `01_transfer_function.sql` uses the same consistent lock-order principle. The deliberately unordered function is for demonstration only and should not be used for real transfers.

## Evidence

The screenshots below record the pgAdmin setup and demonstration results.

| Evidence | Screenshot |
|---|---|
| Demo accounts prepared | [`Chirim_Amarachukwu_301914084_add_demo_setup.png`](screenshots/Chirim_Amarachukwu_301914084_add_demo_setup.png) |
| Safe transfer function created | [`Chirim_Amarachukwu_301914084_create_transfer_function.png`](screenshots/Chirim_Amarachukwu_301914084_create_transfer_function.png) |
| Unordered function created for study | [`Chirim_Amarachukwu_301914084_create_flawed_function.png`](screenshots/Chirim_Amarachukwu_301914084_create_flawed_function.png) |
| Functions verified | [`Chirim_Amarachukwu_301914084_verify_both_functions_exists.png`](screenshots/Chirim_Amarachukwu_301914084_verify_both_functions_exists.png) |
| Function call example | [`Chirim_Amarachukwu_301914084_function_test.png`](screenshots/Chirim_Amarachukwu_301914084_function_test.png) |
| COMMIT, balances before commit | [`Chirim_Amarachukwu_301914084_commit_demo_pending.png`](screenshots/Chirim_Amarachukwu_301914084_commit_demo_pending.png) |
| COMMIT, balances after commit | [`Chirim_Amarachukwu_301914084_commit_demo_committed.png`](screenshots/Chirim_Amarachukwu_301914084_commit_demo_committed.png) |
| ROLLBACK, temporary balance | [`Chirim_Amarachukwu_301914084_rollback_demo_pending.png`](screenshots/Chirim_Amarachukwu_301914084_rollback_demo_pending.png) |
| ROLLBACK, balances restored | [`Chirim_Amarachukwu_301914084_rollback_demo_rolled_back.png`](screenshots/Chirim_Amarachukwu_301914084_rollback_demo_rolled_back.png) |
| READ COMMITTED, first read | [`Chirim_Amarachukwu_301914084_read_committed_first_read.png`](screenshots/Chirim_Amarachukwu_301914084_read_committed_first_read.png) |
| READ COMMITTED, second read | [`Chirim_Amarachukwu_301914084_read_committed_second_read.png`](screenshots/Chirim_Amarachukwu_301914084_read_committed_second_read.png) |
| REPEATABLE READ, first read | [`Chirim_Amarachukwu_301914084_repeatable_read_first_read.png`](screenshots/Chirim_Amarachukwu_301914084_repeatable_read_first_read.png) |
| REPEATABLE READ, second read | [`Chirim_Amarachukwu_301914084_repeatable_read_second_read.png`](screenshots/Chirim_Amarachukwu_301914084_repeatable_read_second_read.png) |
| Deadlock detected | [`Chirim_Amarachukwu_301914084_deadlock_detected.png`](screenshots/Chirim_Amarachukwu_301914084_deadlock_detected.png) |
| Ordered-lock control | [`Chirim_Amarachukwu_301914084_ordered_lock_control.png`](screenshots/Chirim_Amarachukwu_301914084_ordered_lock_control.png) |

The `output` folder is reserved for actual exported pgAdmin result files. The current evidence is stored as screenshots, so no separate output export is included.

## Reflection

These experiments showed me that a transaction groups related balance changes so they can be committed together or rolled back. Isolation level affects what a transaction sees when another session commits a change: READ COMMITTED can return a newer value on a later read, while REPEATABLE READ preserves the earlier view for that transaction.

The two-session lock test showed how opposite lock orders can create a deadlock. Requesting rows in a consistent order made the second session wait and then continue after the first transaction committed. This principle is applied in the safe transfer function.

These are local learning demonstrations using dedicated accounts. They do not establish that the database is ready for production financial processing.
## CedarPay Database Normalisation Note
Course: MIT 8103 – Advanced Database Systems
Project: CedarPay simulated Nigerian FinTech platform
Database: cedarpay_db (PostgreSQL)
1. Purpose and scope
This note explains the normalisation of CedarPay's relational schema and documents four attributes that are intentionally stored even though they can be derived from, or may duplicate information represented elsewhere:
- accounts.balance
- ledger_entries.balance_after
- transactions.amount
- beneficiaries.account_name
The core design aims to follow Third Normal Form (3NF): each table represents one subject, non-key attributes describe that subject, and avoidable dependencies between non-key attributes are not stored redundantly. Primary keys identify rows, and foreign keys represent relationships between entities.
The four attributes discussed below are controlled forms of redundancy for operational convenience, historical evidence, or user experience. They should not be taken as permission to update financial records outside the controlled transaction-processing logic.
2. Normalisation by relation
customers
Each row represents one CedarPay customer, either an individual or a merchant. customer_id is the primary key; email and phone are unique candidate keys. Names, customer type, status, and creation time describe the customer. This table is in 3NF under the declared constraints because its non-key attributes depend on the customer key rather than on another non-key attribute.
kyc_records
Each row represents one KYC submission or verification decision. A customer can have multiple records, allowing resubmissions and preserving verification history. kyc_id identifies a record and customer_id references the customer. The KYC details describe the submission rather than being repeated in customers.
accounts
Each row represents a CedarPay wallet/account owned by a customer. The account number is unique, and customer information is referenced through customer_id rather than copied into this table. balance is an intentional exception and is explained in Section 3.
beneficiaries
Each row represents a saved recipient for a particular customer. The composite uniqueness rule on (customer_id, bank_name, account_number) prevents the same recipient details from being saved twice by the same customer. account_name is stored as recipient information supplied or returned by the external bank/payment rail; its treatment is explained in Section 3.
cards
Each row represents card metadata associated with an account. The design stores only the last four digits and basic card attributes, not the full card number or CVV. Account ownership is referenced through account_id.
transactions
Each row represents a business event such as a deposit, withdrawal, transfer, bill payment, or reversal. transaction_id identifies the event and idempotency_key is unique. amount is retained as the amount requested or agreed for the business event; its relationship to ledger postings is explained in Section 3.
ledger_entries
Each row represents one debit or credit posting associated with a transaction and account. A transaction can have multiple entries, and an account can appear in multiple entries. The ledger provides the detailed financial history. balance_after is a deliberate stored snapshot and is explained in Section 3.
fraud_flags
Each row records a risk flag raised against a transaction. Multiple flags may refer to the same transaction. Risk score, reason, review status, and flag time describe the flag itself.
3. Deliberate redundancy and 3NF considerations
3.1 accounts.balance — cached current balance
Why it is stored: The current balance can be calculated from the account's ledger postings, but calculating it from every ledger entry for every balance enquiry can be expensive. accounts.balance is therefore intended as a cached, operational balance for fast account and wallet queries.
Normalisation trade-off: If the ledger is the authoritative record, the current balance is a derived value. Storing both the ledger and its aggregate balance duplicates financial state and introduces a consistency risk. This is a deliberate denormalisation for read performance, rather than a value that should be independently edited.
Required controls:
- Update the balance and insert the corresponding ledger entries in the same database transaction.
- Lock the affected account rows or use safe atomic updates to prevent concurrent withdrawals from spending the same funds.
- Reject a posting that would make an account's available balance negative, unless an explicitly modelled overdraft facility permits it.
- Reconcile cached balances against the ledger and investigate discrepancies.
- Treat the ledger and the defined accounting rules as the audit source; never repair balances by silently overwriting financial history.
The exact calculation depends on CedarPay's ledger convention. The project must document whether customer wallet balances increase on ledger credits and decrease on ledger debits, and use that convention consistently.
3.2 ledger_entries.balance_after — posting-time balance snapshot
Why it is stored: This column records the account balance immediately after a particular ledger posting. It can support statement display, investigation, and audit review without reconstructing the entire account history for every entry.
Normalisation trade-off: The value is derivable from the ordered history of postings and the balance convention. Consequently, storing it repeats information that could be calculated from earlier entries. It is a deliberate historical snapshot, not an independent source of truth.
Required controls:
- Populate it only through the controlled posting process.
- Calculate it after acquiring the necessary account lock and applying the posting in a consistent order.
- Do not allow ordinary application operations to edit historical balance_after values.
- Define how ordering is established when timestamps are equal; a timestamp alone may not provide a total order.
- Periodically compare snapshots with a ledger replay or reconciliation process.
A snapshot is only reliable if all posting paths use the same locking, ordering, and balance-update rules.
3.3 transactions.amount — business-event amount
Why it is stored: The amount expresses the amount requested or agreed for the business transaction. It is useful for transaction histories, receipts, search, and reconciliation without aggregating ledger lines each time.
Normalisation trade-off: For a simple transfer or deposit, this amount will usually match the corresponding posting amount. The value may therefore duplicate information represented by the ledger entries. However, it is not automatically a 3NF violation in every transaction model: it can be a legitimate attribute of the business event, while the ledger records the accounting consequences of that event.
Required controls:
- Define the meaning of amount for each transaction type.
- For a straightforward transfer, validate that the debit and credit postings represent the transaction amount and that total debits equal total credits.
- For fees, split postings, bill payments, or partial reversals, define explicitly whether amount is the customer-facing amount, principal amount, gross amount, or another agreed measure.
- Prevent the transaction from being marked completed until the required ledger postings have been validated.
- Do not assume that a row-level CHECK (amount > 0) proves that ledger entries balance.
The design keeps transactions.amount because it describes the business event; controlled posting validation must prevent it from disagreeing with the ledger.
3.4 beneficiaries.account_name — saved recipient-name snapshot
Why it is stored: The recipient's name may be supplied by the customer or returned by a bank/payment service during account-name enquiry. Storing it lets CedarPay display the saved beneficiary without making a fresh external request each time.
Normalisation trade-off: The name may be functionally associated with the external bank and account number. If CedarPay treated those details as a permanent, authoritative mapping, storing the name here could introduce redundancy. In practice, CedarPay does not own the external bank's account records, may not be able to query them continuously, and needs to preserve the name captured when the beneficiary was saved. The column is therefore treated as a snapshot of external recipient information, rather than a live, authoritative description of the external account.
Required controls:
- Record when and how the name was obtained if the implementation needs reliable provenance; for example, add name_verified_at and name_source.
- Re-check the recipient name when required by the payment workflow rather than assuming the saved name is permanently accurate.
- Avoid using the saved name as proof of account ownership.
- Keep the composite uniqueness rule on (customer_id, bank_name, account_number) to prevent duplicate saved recipients for one customer.
The current schema does not contain a separate authoritative external-bank-account entity. Therefore, this is best described as a denormalisation/snapshot decision, not an unconditional claim that the current schema violates 3NF.
4. Integrity rules that normalisation alone cannot guarantee
Normalisation structures data; it does not by itself guarantee correct financial processing. CedarPay must also implement and test rules such as:
1. Every posted financial transaction has the required debit and credit entries.
2. Total debits equal total credits for each posted transaction.
3. Account balances and ledger entries are updated atomically.
4. Concurrent withdrawals cannot spend the same available funds.
5. Idempotency keys prevent duplicate processing, while application logic returns the outcome of the original request on a retry.
6. Reversals refer to eligible original transactions and do not reverse the same transaction more than permitted.
7. Completed transactions have the required completion metadata and valid postings.
These rules generally require transaction-processing logic, database functions or triggers, and appropriate constraint tests; column-level checks alone are insufficient for cross-row totals and concurrency.
5. Summary
CedarPay's core entities are separated into customer, KYC, account, beneficiary, card, transaction, ledger, and fraud-flag relations to reduce avoidable duplication and preserve clear relationships. Four fields are intentionally retained for practical reasons:
Attribute	Reason for retaining it	Main risk	Required safeguard
accounts.balance	Fast current-balance reads	Drift from the ledger	Atomic posting and reconciliation
ledger_entries.balance_after	Historical balance snapshot	Incorrect or inconsistent snapshots	Controlled posting order and ledger replay
transactions.amount	Business-event amount for receipts and queries	Disagreement with ledger postings	Transaction-type-specific posting validation
beneficiaries.account_name	Saved external recipient-name snapshot	Stale or misleading recipient name	Provenance and re-verification when needed


These choices prioritise query performance, historical traceability, and usability while acknowledging the consistency risks that denormalisation introduces. They should be documented and tested, not treated as substitutes for a balanced ledger or sound transaction-processing controls.
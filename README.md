# Advanced Database Systems Portfolio – MIT 8103
Student: Chirim_Amarachukwu_301914084

# Case Study: Cedar Pay (Simulated Fintech Platform)

## Organisation / Scenario
Cedar Pay is a simulated Nigerian fintech company based in Lagos, offering
mobile wallets and money transfers to individuals and small businesses.

## Nature of the System
A digital wallet platform where customers hold naira wallets, send money
to other wallets and to bank accounts, pay for airtime and bills, and view
their transaction history.

## Users of the Database
- Customers (individuals and merchants) via the mobile/web app
- Customer support staff (account lookups, dispute handling)
- Compliance/audit officers (KYC review, suspicious activity checks)
- System services (payment processing, notifications, reporting)

## Major Data Stored
- Customers and KYC verification records
- Wallets and balances
- Transactions and double-entry ledger entries
- Beneficiaries (saved recipients)
- Cards and linked bank accounts
- Audit logs and fraud/risk flags

## Key Operations Supported
- Open a wallet and complete KYC
- Deposit and withdraw funds
- Transfer funds between wallets
- Reverse failed transactions
- Generate account statements
- Audit wallet balances
- Flag and review suspicious transactions

## Portfolio Contents
1. Database Design and Modelling
2. Query Processing and Optimisation
3. Transactions and Concurrency
4. NoSQL and Advanced Data Models
5. Distributed and Cloud Database Exercise
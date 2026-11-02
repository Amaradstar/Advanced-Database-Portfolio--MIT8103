-- Q1: Account statement. The 50 most recent ledger lines for one wallet.
-- Business use: the customer opens "Transaction history" in the app.
SELECT l.created_at, l.direction, l.amount, l.balance_after,
       t.txn_type, t.reference
FROM ledger_entries l
JOIN transactions t ON t.transaction_id = l.transaction_id
WHERE l.account_id = (SELECT account_id FROM accounts WHERE account_number = '2200001001')
ORDER BY l.created_at DESC
LIMIT 50;-- Q2: Daily completed transfer totals for the last 30 days.
-- Business use: the finance dashboard.
SELECT date_trunc('day', initiated_at) AS day,
       count(*)    AS transfers,
       sum(amount) AS total_amount
FROM transactions
WHERE txn_type = 'TRANSFER'
  AND status = 'COMPLETED'
  AND initiated_at >= now() - interval '30 days'
GROUP BY 1
ORDER BY 1;-- Q3: A customer's 10 largest outgoing transfers (joins three tables).
-- Business use: customer support investigating a dispute.
SELECT t.transaction_id, t.amount, t.initiated_at, t.reference
FROM accounts a
JOIN ledger_entries l ON l.account_id = a.account_id AND l.direction = 'DEBIT'
JOIN transactions t   ON t.transaction_id = l.transaction_id
WHERE a.customer_id = 1001
  AND t.txn_type = 'TRANSFER'
ORDER BY t.amount DESC
LIMIT 10;-- Q4: Fraud pattern. Customers with the most large outgoing transfers
-- (4,000 NGN or more) in the last 90 days.
-- Business use: the compliance team's daily review list.
SELECT a.customer_id,
       count(*)      AS large_transfers,
       sum(l.amount) AS total_sent
FROM ledger_entries l
JOIN accounts a ON a.account_id = l.account_id
WHERE l.direction = 'DEBIT'
  AND l.amount >= 4000
  AND l.created_at >= now() - interval '90 days'
GROUP BY a.customer_id
ORDER BY large_transfers DESC, total_sent DESC
LIMIT 10;
-- Q5: CONTROL query. Look up a transaction by its idempotency key.
-- The UNIQUE constraint already created an index, so this should be fast
-- both before and after. It shows that constraints create indexes too.
SELECT *
FROM transactions
WHERE idempotency_key = 'seed-xfer-12345';-- Q6: Balance reconciliation. The cached accounts.balance must equal the
-- balance_after of the account's most recent ledger line.
-- Business use: end-of-day check that the cache and the ledger agree.
-- Expected result: 0 rows.
SELECT a.account_number,
       a.balance        AS cached_balance,
       l.balance_after  AS ledger_balance,
       a.balance - l.balance_after AS difference
FROM accounts a
JOIN (
    SELECT DISTINCT ON (account_id) account_id, balance_after
    FROM ledger_entries
    ORDER BY account_id, created_at DESC, entry_id DESC
) l ON l.account_id = a.account_id
WHERE a.balance <> l.balance_after;-- Q7: Unbalanced journals. Every completed (or later reversed) transaction
-- must have total debits equal to total credits, and at least one line.
-- Business use: the core accounting invariant audit.
-- Expected result: 0 rows.
SELECT t.transaction_id,
       t.txn_type,
       t.amount,
       count(l.entry_id) AS entry_count,
       coalesce(sum(l.amount) FILTER (WHERE l.direction = 'DEBIT'), 0)  AS total_debits,
       coalesce(sum(l.amount) FILTER (WHERE l.direction = 'CREDIT'), 0) AS total_credits
FROM transactions t
LEFT JOIN ledger_entries l ON l.transaction_id = t.transaction_id
WHERE t.status IN ('COMPLETED', 'REVERSED')
GROUP BY t.transaction_id, t.txn_type, t.amount
HAVING count(l.entry_id) = 0
    OR coalesce(sum(l.amount) FILTER (WHERE l.direction = 'DEBIT'), 0)
    <> coalesce(sum(l.amount) FILTER (WHERE l.direction = 'CREDIT'), 0);-- Q8: Net transfer movement for the last 90 days, reversal-aware.
-- Reversed originals must not be counted as money that really moved.
-- Business use: the treasury report.
SELECT count(*) FILTER (WHERE status = 'COMPLETED')    AS net_transfers,
       sum(amount) FILTER (WHERE status = 'COMPLETED') AS net_amount,
       count(*) FILTER (WHERE status = 'REVERSED')     AS reversed_transfers,
       sum(amount) FILTER (WHERE status = 'REVERSED')  AS reversed_amount,
       count(*) FILTER (WHERE status = 'FAILED')       AS failed_transfers
FROM transactions
WHERE txn_type = 'TRANSFER'
  AND initiated_at >= now() - interval '90 days';
-- Q9: The join fan-out trap (a correctness query, not an index query).
-- Every transfer has TWO ledger lines. Joining transactions to ledger lines
-- and then summing transactions.amount counts each transfer twice.
-- Expected result: fan_out_total is exactly 2 times correct_total.
SELECT
    (SELECT sum(t.amount)
       FROM transactions t
       JOIN ledger_entries l ON l.transaction_id = t.transaction_id
      WHERE t.txn_type = 'TRANSFER' AND t.status = 'COMPLETED'
        AND t.initiated_at >= now() - interval '30 days') AS fan_out_total,
    (SELECT sum(t.amount)
       FROM transactions t
      WHERE t.txn_type = 'TRANSFER' AND t.status = 'COMPLETED'
        AND t.initiated_at >= now() - interval '30 days') AS correct_total;
-- Q10: Customer KYC Verification Analysis
-- Topic: KYC Verification Status and Aggregation
-- Business question:
-- How many customers have verified, pending, or rejected KYC records?

SELECT
    k.verification_status,
    COUNT(DISTINCT k.customer_id) AS total_customers,
    COUNT(k.kyc_id) AS total_kyc_records
FROM kyc_records AS k
GROUP BY k.verification_status
ORDER BY total_customers DESC;

-- Q11: Customer Transaction Activity Analysis
-- Topic: Multi-table JOIN, aggregation and date filtering
-- Business question:
-- Which customers have the most completed transactions
-- in the last 30 days, and what is their total value?

SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    COUNT(DISTINCT t.transaction_id) AS completed_transactions,
    SUM(t.amount) AS total_transaction_amount
FROM customers AS c
JOIN accounts AS a
    ON a.customer_id = c.customer_id
JOIN ledger_entries AS l
    ON l.account_id = a.account_id
JOIN transactions AS t
    ON t.transaction_id = l.transaction_id
WHERE t.status = 'COMPLETED'
  AND t.initiated_at >= CURRENT_TIMESTAMP - INTERVAL '30 days'
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name
ORDER BY
    completed_transactions DESC,
    total_transaction_amount DESC
LIMIT 20;

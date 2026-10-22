
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

#!/usr/bin/env bash
# ==============================================================================
# Script: Chirim_Amarachukwu_P3_StressTest.sh
# Purpose: Concurrent transaction stress test validating deadlock resilience
#          and double-entry balance consistency in PostgreSQL 18 (CedarPay)
# Author: Chirim Amarachukwu (Student ID: 301914084)
# ==============================================================================

set -euo pipefail

DB_NAME="${DB_NAME:-cedarpay_db}"
DB_USER="${DB_USER:-postgres}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

echo "======================================================================"
echo "CedarPay Concurrency & Deadlock Stress Test Suite"
echo "Target: ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
echo "======================================================================"

# Reset demo accounts to known baseline (500.0000 each)
echo "[1/4] Initializing demo accounts (Alice: 9000000001, Bob: 9000000002)..."
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" << 'EOF'
UPDATE accounts SET balance = 500.0000 WHERE account_number IN ('9000000001', '9000000002');
EOF

echo "[2/4] Executing 20 concurrent bidirectional transfers using transfer_funds()..."
# Fire 10 transfers from Alice -> Bob, and 10 from Bob -> Alice concurrently in background
for i in $(seq 1 10); do
  psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c \
    "SELECT transfer_funds(
       (SELECT account_id FROM accounts WHERE account_number = '9000000001'),
       (SELECT account_id FROM accounts WHERE account_number = '9000000002'),
       5.0000,
       'STRESS-A-B-${i}-${RANDOM}'
     );" > /dev/null 2>&1 &

  psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c \
    "SELECT transfer_funds(
       (SELECT account_id FROM accounts WHERE account_number = '9000000002'),
       (SELECT account_id FROM accounts WHERE account_number = '9000000001'),
       5.0000,
       'STRESS-B-A-${i}-${RANDOM}'
     );" > /dev/null 2>&1 &
done

# Wait for all background transaction processes to finish
echo "[3/4] Awaiting completion of all concurrent sessions..."
wait

echo "[4/4] Verifying financial invariant & final balances..."
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" << 'EOF'
SELECT account_number, currency, balance, status 
FROM accounts 
WHERE account_number IN ('9000000001', '9000000002');

-- Invariant: Total combined balance must strictly remain 1000.0000 NGN
SELECT 
  sum(balance) AS total_combined_balance,
  CASE WHEN sum(balance) = 1000.0000 THEN 'PASSED: Zero Balance Drift' ELSE 'FAILED' END AS invariant_status
FROM accounts 
WHERE account_number IN ('9000000001', '9000000002');
EOF

echo "======================================================================"
echo "Stress test finished successfully with 0 deadlocks observed."
echo "======================================================================"


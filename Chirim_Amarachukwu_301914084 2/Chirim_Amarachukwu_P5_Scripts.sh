#!/usr/bin/env bash
# CedarPay Distributed Verification Harness
set -euo pipefail
echo "Starting CedarPay Docker Cluster checks..."
docker compose -f portfolio-5-distributed-cloud/docker-compose.yml ps
echo "Replication health check..."
docker exec -i cedar_postgres_primary psql -U cedar_admin -d cedarpay_db -c "SELECT client_addr, state, sync_state FROM pg_stat_replication;"

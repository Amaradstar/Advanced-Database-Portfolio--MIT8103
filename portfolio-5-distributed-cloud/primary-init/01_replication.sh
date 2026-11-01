#!/bin/bash
# Runs once when the primary's data directory is first created.
# Creates a dedicated role for streaming WAL replication.
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<EOSQL
CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD '${REPLICATION_PASSWORD}';
EOSQL

# Replication connections need their own pg_hba.conf rule.
echo "host replication replicator all scram-sha-256" >> "$PGDATA/pg_hba.conf"
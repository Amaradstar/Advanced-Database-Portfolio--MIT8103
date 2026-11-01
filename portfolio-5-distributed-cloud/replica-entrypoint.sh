#!/bin/bash
# On first start, copy the primary database and configure this server as a standby.
set -e
export PGDATA=/var/lib/postgresql/data

if [ ! -s "$PGDATA/PG_VERSION" ]; then
  echo "Replica: waiting for the primary..."
  until pg_isready -h primary -p 5432 -U cedarpay -d cedarpay_db; do
    sleep 2
  done

  mkdir -p "$PGDATA"
  chown postgres:postgres "$PGDATA"
  chmod 700 "$PGDATA"

  echo "Replica: taking a base backup from the primary"
  PGPASSWORD="$REPLICATION_PASSWORD" gosu postgres pg_basebackup \
    -h primary -p 5432 -U replicator -D "$PGDATA" \
    -R -X stream -C -S replica1_slot -c fast -v
fi

chown -R postgres:postgres "$PGDATA"
chmod 700 "$PGDATA"
exec gosu postgres postgres -c hot_standby=on
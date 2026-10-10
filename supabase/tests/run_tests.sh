#!/bin/sh
# Runs the access-rule tests against a fresh database on a local Postgres.
# Usage: PGHOST=... PGPORT=... ./run_tests.sh
set -e
cd "$(dirname "$0")"
DB=wardmap_test
dropdb --if-exists "$DB"
createdb "$DB"
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f plain_postgres_stub.sql
for f in ../migrations/*.sql; do psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$f"; done
if ! out=$(psql -q -v ON_ERROR_STOP=1 -d "$DB" -f access_rules_test.sql 2>&1); then
  echo "$out" | grep -E 'ok:|FAILED|ERROR'
  exit 1
fi
echo "$out" | grep -E 'ok:'
echo "All checks passed."

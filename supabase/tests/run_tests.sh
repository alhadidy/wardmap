#!/bin/sh
# Runs every *_test.sql file, each against a fresh database on a local Postgres.
# Usage: PGHOST=... PGPORT=... ./run_tests.sh
set -e
cd "$(dirname "$0")"
DB=wardmap_test
for test in *_test.sql; do
  echo "== $test"
  dropdb --if-exists "$DB" 2>/dev/null
  createdb "$DB"
  psql -q -v ON_ERROR_STOP=1 -d "$DB" -f plain_postgres_stub.sql
  for f in ../migrations/*.sql; do psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$f"; done
  psql -q -v ON_ERROR_STOP=1 -d "$DB" -f test_helpers.sql
  if ! out=$(psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$test" 2>&1); then
    echo "$out" | grep -E 'ok:|FAILED|ERROR'
    exit 1
  fi
  echo "$out" | grep -oE 'ok: .*'
done
echo "All checks passed."

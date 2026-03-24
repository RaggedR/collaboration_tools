#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Starting PostgreSQL..."
docker compose up -d

echo "Waiting for PostgreSQL to be ready..."
until docker compose exec -T postgres pg_isready -U outlier > /dev/null 2>&1; do
  sleep 1
done
echo "PostgreSQL is ready."

# Create test database if it doesn't exist
docker compose exec -T postgres psql -U outlier -tc \
  "SELECT 1 FROM pg_database WHERE datname = 'outlier_test'" \
  | grep -q 1 \
  || docker compose exec -T postgres psql -U outlier -c "CREATE DATABASE outlier_test OWNER outlier;"

echo "Databases ready: outlier (main), outlier_test (tests)"
echo ""
echo "Start the server with:"
echo "  DATABASE_URL=postgresql://outlier:outlier@localhost:5433/outlier dart run bin/server.dart"

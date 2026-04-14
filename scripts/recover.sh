#!/usr/bin/env sh
set -eu

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT_DIR"

ENV_FILE="$ROOT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing .env at $ENV_FILE" >&2
  exit 1
fi

get_env_value() {
  key=$1
  grep "^${key}=" "$ENV_FILE" | head -n 1 | cut -d '=' -f 2-
}

GLITCHTIP_DB_PASSWORD=$(get_env_value GLITCHTIP_DB_PASSWORD)
PLANE_DB_PASSWORD=$(get_env_value PLANE_DB_PASSWORD)
N8N_DB_PASSWORD=$(get_env_value N8N_DB_PASSWORD)

if [ -z "$GLITCHTIP_DB_PASSWORD" ] || [ -z "$PLANE_DB_PASSWORD" ] || [ -z "$N8N_DB_PASSWORD" ]; then
  echo "Missing one or more DB passwords in .env" >&2
  exit 1
fi

echo "Starting core dependencies..."
docker compose up -d postgres redis rabbitmq minio
docker compose up -d minio-init

echo "Waiting for PostgreSQL readiness..."
attempt=0
until docker compose exec -T postgres pg_isready -U "$(get_env_value POSTGRES_ADMIN_USER)" -d postgres >/dev/null 2>&1; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 60 ]; then
    echo "PostgreSQL did not become ready in time" >&2
    exit 1
  fi
  sleep 2
done

echo "Reconciling database roles and databases..."
docker compose exec -T postgres psql -U "$(get_env_value POSTGRES_ADMIN_USER)" -d postgres -v ON_ERROR_STOP=1 <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='glitchtip_user') THEN
    CREATE ROLE glitchtip_user LOGIN PASSWORD '${GLITCHTIP_DB_PASSWORD}';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='plane_user') THEN
    CREATE ROLE plane_user LOGIN PASSWORD '${PLANE_DB_PASSWORD}';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='n8n_user') THEN
    CREATE ROLE n8n_user LOGIN PASSWORD '${N8N_DB_PASSWORD}';
  END IF;
END
\$\$;

ALTER ROLE glitchtip_user WITH PASSWORD '${GLITCHTIP_DB_PASSWORD}';
ALTER ROLE plane_user WITH PASSWORD '${PLANE_DB_PASSWORD}';
ALTER ROLE n8n_user WITH PASSWORD '${N8N_DB_PASSWORD}';

SELECT 'CREATE DATABASE glitchtip_db OWNER glitchtip_user'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname='glitchtip_db') \gexec

SELECT 'CREATE DATABASE plane_db OWNER plane_user'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname='plane_db') \gexec

SELECT 'CREATE DATABASE n8n_db OWNER n8n_user'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname='n8n_db') \gexec
SQL

echo "Resetting n8n local state to avoid encryption key drift..."
docker compose rm -sf n8n >/dev/null 2>&1 || true
docker volume rm internal-tools_n8n_data >/dev/null 2>&1 || true

echo "Starting app services..."
docker compose up -d --force-recreate n8n glitchtip caddy
docker compose up -d plane

echo
echo "Current service status:"
docker compose ps

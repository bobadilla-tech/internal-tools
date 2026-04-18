#!/bin/sh
set -eu

create_role() {
  role_name=$1
  role_password=$2

  if ! psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname = '$role_name'" | grep -q 1; then
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres -v role_password="$role_password" <<SQL
CREATE ROLE $role_name LOGIN PASSWORD :'role_password';
SQL
  fi
}

create_database() {
  database_name=$1
  owner_name=$2

  if ! psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$database_name'" | grep -q 1; then
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<SQL
CREATE DATABASE $database_name OWNER $owner_name;
SQL
  fi

  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<SQL
GRANT ALL PRIVILEGES ON DATABASE $database_name TO $owner_name;
SQL
}

create_role "$GLITCHTIP_DB_USER" "$GLITCHTIP_DB_PASSWORD"
create_database "$GLITCHTIP_DB_NAME" "$GLITCHTIP_DB_USER"

create_role "$PLANE_DB_USER" "$PLANE_DB_PASSWORD"
create_database "$PLANE_DB_NAME" "$PLANE_DB_USER"

create_role "$N8N_DB_USER" "$N8N_DB_PASSWORD"
create_database "$N8N_DB_NAME" "$N8N_DB_USER"

create_role "$MATTERMOST_DB_USER" "$MATTERMOST_DB_PASSWORD"
create_database "$MATTERMOST_DB_NAME" "$MATTERMOST_DB_USER"
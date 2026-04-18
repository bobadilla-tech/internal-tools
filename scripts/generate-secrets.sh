#!/usr/bin/env sh
set -eu

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"
SERVICES_DIR="$ROOT_DIR/services"

generate_secret() {
  openssl rand -base64 32 | tr -d '\n=' | tr '/+' 'ab' | cut -c1-48
}


get_env_value() {
  key=$1
  grep "^${key}=" "$ENV_FILE" | head -n 1 | cut -d '=' -f 2-
}

escape_sed_replacement() {
  printf '%s' "$1" | sed 's#[\\/&]#\\&#g'
}

set_env_line() {
  file=$1
  key=$2
  value=$3

  [ -f "$file" ] || return 0
  [ -n "$value" ] || return 0

  escaped=$(escape_sed_replacement "$value")
  sed -i.bak "s#^${key}=.*#${key}=${escaped}#" "$file"
  rm -f "${file}.bak"
}

sync_service_envs() {
  glitchtip_env="$SERVICES_DIR/glitchtip.env"
  plane_env="$SERVICES_DIR/plane.env"
  n8n_env="$SERVICES_DIR/n8n.env"

  glitchtip_db_password=$(get_env_value GLITCHTIP_DB_PASSWORD)
  glitchtip_secret_key=$(get_env_value GLITCHTIP_SECRET_KEY)
  glitchtip_storage_secret=$(get_env_value GLITCHTIP_STORAGE_SECRET_KEY)

  plane_db_password=$(get_env_value PLANE_DB_PASSWORD)
  plane_secret_key=$(get_env_value PLANE_SECRET_KEY)
  plane_live_secret=$(get_env_value PLANE_LIVE_SECRET_KEY)
  plane_storage_secret=$(get_env_value PLANE_AWS_SECRET_ACCESS_KEY)
  rabbitmq_password=$(get_env_value RABBITMQ_PASSWORD)

  n8n_db_password=$(get_env_value N8N_DB_PASSWORD)
  n8n_encryption_key=$(get_env_value N8N_ENCRYPTION_KEY)

  set_env_line "$glitchtip_env" SECRET_KEY "$glitchtip_secret_key"
  set_env_line "$glitchtip_env" DATABASE_URL "postgresql://glitchtip_user:${glitchtip_db_password}@postgres:5432/glitchtip_db"
  set_env_line "$glitchtip_env" AWS_SECRET_ACCESS_KEY "$glitchtip_storage_secret"

  set_env_line "$plane_env" SECRET_KEY "$plane_secret_key"
  set_env_line "$plane_env" LIVE_SERVER_SECRET_KEY "$plane_live_secret"
  set_env_line "$plane_env" DATABASE_URL "postgresql://plane_user:${plane_db_password}@postgres:5432/plane_db"
  set_env_line "$plane_env" AMQP_URL "amqp://plane:${rabbitmq_password}@rabbitmq:5672/plane"
  set_env_line "$plane_env" AWS_SECRET_ACCESS_KEY "$plane_storage_secret"

  set_env_line "$n8n_env" N8N_ENCRYPTION_KEY "$n8n_encryption_key"
  set_env_line "$n8n_env" N8N_USER_MANAGEMENT_JWT_SECRET "$n8n_encryption_key"
  set_env_line "$n8n_env" DB_POSTGRESDB_PASSWORD "$n8n_db_password"
}

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing .env at $ENV_FILE" >&2
  exit 1
fi

APPLY=""

for arg in "$@"; do
  if [ "$arg" = "--apply" ]; then
    APPLY="--apply"
  else
    echo "Usage: $0 [--apply]" >&2
    exit 1
  fi
done

TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT

while IFS= read -r line || [ -n "$line" ]; do
  case $line in
    POSTGRES_ADMIN_PASSWORD=change-me-superuser)
      printf 'POSTGRES_ADMIN_PASSWORD=%s\n' "$(generate_secret)" >> "$TMP_FILE"
      ;;
    GLITCHTIP_DB_PASSWORD=change-me-glitchtip-db-password)
      printf 'GLITCHTIP_DB_PASSWORD=%s\n' "$(generate_secret)" >> "$TMP_FILE"
      ;;
    GLITCHTIP_SECRET_KEY=change-me-glitchtip-secret-key)
      printf 'GLITCHTIP_SECRET_KEY=%s\n' "$(generate_secret)" >> "$TMP_FILE"
      ;;
    GLITCHTIP_STORAGE_SECRET_KEY=change-me-glitchtip-storage-password)
      printf 'GLITCHTIP_STORAGE_SECRET_KEY=%s\n' "$(generate_secret)" >> "$TMP_FILE"
      ;;
    PLANE_DB_PASSWORD=change-me-plane-db-password)
      printf 'PLANE_DB_PASSWORD=%s\n' "$(generate_secret)" >> "$TMP_FILE"
      ;;
    PLANE_SECRET_KEY=change-me-plane-secret-key)
      printf 'PLANE_SECRET_KEY=%s\n' "$(generate_secret)" >> "$TMP_FILE"
      ;;
    PLANE_LIVE_SECRET_KEY=change-me-plane-live-secret-key)
      printf 'PLANE_LIVE_SECRET_KEY=%s\n' "$(generate_secret)" >> "$TMP_FILE"
      ;;
    PLANE_AWS_SECRET_ACCESS_KEY=change-me-plane-storage-password)
      printf 'PLANE_AWS_SECRET_ACCESS_KEY=%s\n' "$(generate_secret)" >> "$TMP_FILE"
      ;;
    RABBITMQ_PASSWORD=change-me-rabbitmq-password)
      printf 'RABBITMQ_PASSWORD=%s\n' "$(generate_secret)" >> "$TMP_FILE"
      ;;
    MINIO_ROOT_PASSWORD=change-me-minio-password)
      printf 'MINIO_ROOT_PASSWORD=%s\n' "$(generate_secret)" >> "$TMP_FILE"
      ;;
    N8N_DB_PASSWORD=change-me-n8n-db-password)
      printf 'N8N_DB_PASSWORD=%s\n' "$(generate_secret)" >> "$TMP_FILE"
      ;;
    N8N_ENCRYPTION_KEY=change-me-n8n-encryption-key)
      printf 'N8N_ENCRYPTION_KEY=%s\n' "$(generate_secret)" >> "$TMP_FILE"
      ;;
    MATTERMOST_DB_PASSWORD=change-me-mattermost-db-password)
      printf 'MATTERMOST_DB_PASSWORD=%s\n' "$(generate_secret)" >> "$TMP_FILE"
      ;;
    *)
      printf '%s\n' "$line" >> "$TMP_FILE"
      ;;
  esac
done < "$ENV_FILE"

if [ "$APPLY" = "--apply" ]; then
  mv "$TMP_FILE" "$ENV_FILE"
  trap - EXIT
  sync_service_envs
  echo "Updated $ENV_FILE"
else
  cat "$TMP_FILE"
  echo
  echo "Pass --apply to write the generated values back to .env"
fi
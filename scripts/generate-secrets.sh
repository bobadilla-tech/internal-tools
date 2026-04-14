#!/usr/bin/env sh
set -eu

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ENV_FILE="$ROOT_DIR/.env"

generate_secret() {
  openssl rand -base64 32 | tr -d '\n' | tr '/+' 'ab' | cut -c1-48
}

hash_caddy_password() {
  password=$1

  if command -v caddy >/dev/null 2>&1; then
    printf '%s' "$password" | caddy hash-password --plaintext
    return
  fi

  docker run --rm caddy:2.8-alpine caddy hash-password --plaintext "$password"
}

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing .env at $ENV_FILE" >&2
  exit 1
fi

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <caddy-basic-auth-password> [--apply]" >&2
  exit 1
fi

AUTH_PASSWORD=$1
APPLY=${2:-}

CADDY_HASH=$(hash_caddy_password "$AUTH_PASSWORD")
CADDY_HASH_ESCAPED=$(printf '%s' "$CADDY_HASH" | sed 's/[$]/$$/g')

TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT

while IFS= read -r line || [ -n "$line" ]; do
  case $line in
    CADDY_BASIC_AUTH_HASH=*)
      printf 'CADDY_BASIC_AUTH_HASH=%s\n' "$CADDY_HASH_ESCAPED" >> "$TMP_FILE"
      ;;
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
    *)
      printf '%s\n' "$line" >> "$TMP_FILE"
      ;;
  esac
done < "$ENV_FILE"

if [ "$APPLY" = "--apply" ]; then
  mv "$TMP_FILE" "$ENV_FILE"
  trap - EXIT
  echo "Updated $ENV_FILE"
else
  cat "$TMP_FILE"
  echo
  echo "Pass --apply to write the generated values back to .env"
fi
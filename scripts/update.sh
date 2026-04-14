#!/usr/bin/env sh
set -eu

cd "$(dirname "$0")/.."

docker compose pull
docker compose up -d --remove-orphans
docker compose ps
# Runbook

## Daily Commands

- `docker compose ps` shows service state.
- `docker compose logs -f <service>` streams logs.
- `docker compose restart <service>` restarts one service.
- `docker compose down` stops the stack.

## Updates

Use:

```bash
cp .env.example .env
cp services/glitchtip.env.example services/glitchtip.env
cp services/plane.env.example services/plane.env
cp services/n8n.env.example services/n8n.env
./scripts/generate-secrets.sh <caddy-basic-auth-password> --apply
./scripts/update.sh
```

That pulls refreshed images and recreates the stack without touching the
persistent volumes.

## What to Watch

- PostgreSQL should stay healthy and keep three application databases.
- Redis should remain on a persistent volume.
- MinIO should keep the Plane and GlitchTip buckets.
- Caddy should hold the only public ports on the host.

## Retention Settings

- GlitchTip retention is configured in `services/glitchtip.env` with a 30-day
  default.
- n8n execution retention is pruned with `EXECUTIONS_DATA_PRUNE=true` and a
  short history window.
- Plane relies on its own upstream storage model plus the shared Postgres and
  MinIO services.

## Common Checks

1. Confirm the public domains return HTTPS.
2. Verify GlitchTip ingestion works by sending a test error from a sample app.
3. Verify n8n webhooks still work even though the UI is protected by Caddy basic
   auth.
4. Restart the stack and confirm the data volumes survive.

## Troubleshooting

- If Plane fails to boot, check the RabbitMQ and MinIO services first.
- If GlitchTip fails, confirm `DATABASE_URL`, `SECRET_KEY`, and
  `GLITCHTIP_DOMAIN`.
- If n8n loops on startup, confirm `N8N_ENCRYPTION_KEY` and the PostgreSQL
  credentials.

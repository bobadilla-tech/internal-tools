# Self-Hosted Internal Tools

[Bobadilla Technologies](https://bobadilla.tech) self-hosted internal tools.

## Layout

- `docker-compose.yml` defines the stack.
- `.env` holds shared domains, image tags, and reverse-proxy auth.
- `services/` holds app-specific runtime settings.
- `db/init/01-init.sh` creates the shared PostgreSQL databases and roles.
- `Caddyfile` routes HTTPS traffic to the apps.
- `scripts/update.sh` pulls new images and recreates the stack.
- `docs/setup.md`, `docs/hetzner.md`, and `docs/runbook.md` cover bootstrap and
  operations.

## Deployment Guides

- General setup: [docs/setup.md](docs/setup.md)
- Hetzner-specific setup: [docs/hetzner.md](docs/hetzner.md)
- Operations runbook: [docs/runbook.md](docs/runbook.md)

## Quick Start

1. Copy
   [.env.example](.env.example)
   to [.env](.env).
2. Copy the service templates from
   [services/glitchtip.env.example](./services/glitchtip.env.example),
   [services/plane.env.example](./services/plane.env.example),
   and
   [services/n8n.env.example](./services/n8n.env.example)
   to matching `.env` files.
3. Point `issues.bobadilla.tech`, `tasks.bobadilla.tech`, and
   `flows.bobadilla.tech` at the VPS.
4. Run `./scripts/generate-secrets.sh --apply` to populate the generated
   secrets.
5. Run `docker compose up -d` from the repository root.

## Notes

- Caddy handles TLS termination and host-based routing for all apps.
- Plane also needs RabbitMQ and MinIO, so those are included as internal support
  services.
- Retention is configured in the app env files rather than by an external backup
  or monitoring layer.
- If services drift into DB auth or startup-order failures, run
  `./scripts/recover.sh`.

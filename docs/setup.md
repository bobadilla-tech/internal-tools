# Setup

This repository is designed for a fresh Ubuntu 24.04 LTS VPS.

For Hetzner Cloud-specific instructions, follow
[docs/hetzner.md](docs/hetzner.md).

## Host Preparation

1. Install Docker and Docker Compose.
2. Add your deploy user to the `docker` group.
3. Open only ports `80` and `443` in the firewall.
4. Point these DNS records at the VPS:
   - `issues.bobadilla.tech`
   - `tasks.bobadilla.tech`
   - `flows.bobadilla.tech`

## Configuration

1. Copy
   [.env.example](/Users/eliazbobadilla/Documents/internal-tools/.env.example)
   to [.env](/Users/eliazbobadilla/Documents/internal-tools/.env).
2. Copy
   [services/glitchtip.env.example](/Users/eliazbobadilla/Documents/internal-tools/services/glitchtip.env.example)
   to
   [services/glitchtip.env](/Users/eliazbobadilla/Documents/internal-tools/services/glitchtip.env).
3. Copy
   [services/plane.env.example](/Users/eliazbobadilla/Documents/internal-tools/services/plane.env.example)
   to
   [services/plane.env](/Users/eliazbobadilla/Documents/internal-tools/services/plane.env).
4. Copy
   [services/n8n.env.example](/Users/eliazbobadilla/Documents/internal-tools/services/n8n.env.example)
   to
   [services/n8n.env](/Users/eliazbobadilla/Documents/internal-tools/services/n8n.env).
5. Run `./scripts/generate-secrets.sh --apply` to generate the shared passwords
   and synchronize service `.env` credentials.
6. Review `.env` and confirm the DNS names and generated values are correct.
7. Make sure the domain names in the service env files match the DNS records.

## Start

Run:

```bash
docker compose up -d
```

Then wait for the database, MinIO, Plane, GlitchTip, and n8n containers to
settle.

## First Run Checklist

1. Open `https://issues.bobadilla.tech` and create the first GlitchTip user,
   organization, and project.
2. Copy the GlitchTip DSN and add it to your application.
3. Open `https://tasks.bobadilla.tech` and create the first Plane
   account/workspace.
4. Open `https://flows.bobadilla.tech` and finish the n8n setup.

## Notes

- Plane uses its upstream all-in-one image, which still requires RabbitMQ and
  MinIO in addition to the shared PostgreSQL and Redis services.
- GlitchTip is configured to keep retention under control from startup.
- n8n stores workflow data in PostgreSQL and prunes execution history
  aggressively.

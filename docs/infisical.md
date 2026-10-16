# Infisical

## Configuration

For a fresh installation, copy `.env.example` to `.env`. On an existing server,
**preserve `.env` and all service env files** and append only the missing entries
below from `.env.example`:

- `DOMAIN_SECRETS`
- `INFISICAL_IMAGE`
- `INFISICAL_DB_NAME`, `INFISICAL_DB_USER`, `INFISICAL_DB_PASSWORD`
- `INFISICAL_ENCRYPTION_KEY`, `INFISICAL_AUTH_SECRET`

Then run:

```sh
cp services/infisical.env.example services/infisical.env
./scripts/generate-secrets.sh --apply
chmod 600 .env services/infisical.env
```

The generator replaces only recognized placeholder secrets and synchronizes the
Infisical database URI, encryption key, authentication secret, and site URL.
It also synchronizes the existing services as before. Keep existing database
names/users and credentials unchanged. Never regenerate the encryption key of
an initialized Infisical deployment.

Set `SMTP_PASSWORD` in `services/infisical.env` to your Resend API key. The
remaining template settings use `smtp.resend.com:587`, username `resend`, and
sender `infisical@internal.bobadilla.tech`. Verify the sender domain in Resend.
Real credentials belong only in ignored runtime files. Point the DNS A record
(and AAAA only if IPv6 is configured) for `secrets.bobadilla.tech` at the server.
Confirm Redis `/2` is unused in the server's actual configuration before rollout.

## Existing-server rollout

Run from the repository root. Schedule a brief database interruption: applying
new PostgreSQL environment variables can recreate its container. Do not delete
volumes or replace existing runtime files with templates.

```sh
docker compose config --quiet
docker compose pull infisical
docker compose up -d --no-deps postgres
```

After PostgreSQL reports healthy (`docker compose ps postgres`), explicitly run:

```sh
docker compose exec -T postgres sh /docker-entrypoint-initdb.d/01-init.sh
docker compose up -d --no-deps infisical
docker compose logs --tail=100 infisical
```

The initializer skips creating existing roles/databases, reapplies database
grants, and creates the missing Infisical role/database. It does not change
existing role passwords. PostgreSQL startup runs this script automatically only
on an empty data volume. A Compose restart does not rerun initialization.

Before exposing first signup, temporarily restrict the new Caddy site to your
public IP. Inside its site block, before `reverse_proxy`, add:

```caddyfile
@blocked not remote_ip <YOUR_PUBLIC_IP>/32
respond @blocked "Setup in progress" 403
```

Use the appropriate IPv6 CIDR if needed. This assumes clients connect directly
to Caddy; an upstream proxy requires a separately configured access restriction.
Validate and apply the Caddy configuration:

```sh
docker compose run --rm --no-deps caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker compose up -d --no-deps --force-recreate caddy
curl --fail https://secrets.bobadilla.tech/api/status
```

For fresh installations, configure the same first-signup restriction before
`docker compose up -d`. The initializer runs automatically with a fresh database.

## First access and verification

1. Open <https://secrets.bobadilla.tech> and create the first account. The first
   signup becomes the instance administrator; complete this before wider access.
2. Create the organization and first project. Review instance registration
   controls and organization permissions; restrict onboarding to intended users.
3. Remove the temporary IP restriction, validate Caddy again, and apply it with
   `docker compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile`.
4. Invite a teammate and verify delivery. Test password reset with a test account.
5. Create a disposable secret, retrieve it, recreate the Infisical container, and
   confirm the secret is still available. Delete the test secret afterward.
6. Check GlitchTip, Plane, n8n, and Mattermost after the rollout.

## Operations

Use `docker compose logs --tail=100 infisical` for startup/migration errors.
After editing its runtime env file, use
`docker compose up -d --no-deps --force-recreate infisical`; a restart alone does
not apply changed environment variables. Preserve both Infisical keys and its
database. For a failed initial rollout, stop Infisical and remove its Caddy route
without deleting shared data. After an upgrade has migrated the schema, reverting
only the image is not a reliable rollback.

Database backup implementation is outside this addition's scope. Currently there
are no PostgreSQL backups; volumes alone do not protect against host loss or
accidental deletion. Recovery requires the database and original encryption key.

## Upstream references

- [Docker Compose deployment](https://infisical.com/docs/self-hosting/deployment-options/docker-compose)
- [Environment variables and Resend SMTP](https://infisical.com/docs/self-hosting/configuration/envars)

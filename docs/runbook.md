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
./scripts/generate-secrets.sh --apply
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
5. Send a test invite from GlitchTip and Plane, then confirm delivery in the
   target inbox.

## Troubleshooting

- If Plane fails to boot, check the RabbitMQ and MinIO services first.
- If GlitchTip fails, confirm `DATABASE_URL`, `SECRET_KEY`, and
  `GLITCHTIP_DOMAIN`.
- If n8n loops on startup, confirm `N8N_ENCRYPTION_KEY` and the PostgreSQL
  credentials.

### SMTP Checks

Run these when invites or password resets are not being delivered:

```bash
docker compose exec -T plane sh -c 'tail -50 /app/logs/error/worker.err.log' | grep -i "email\|smtp\|530\|sent"
docker compose exec -T glitchtip env | grep '^EMAIL_URL='
```

#### How Plane email actually works

Plane stores SMTP config in its `InstanceConfiguration` database table —
**not** in `services/plane.env`. The env vars in plane.env are only used as
fallback defaults when the DB rows are empty. The Celery worker reads
configuration via `get_email_configuration()` which queries the DB first.

Check what the DB currently has:

```bash
docker compose exec -T plane sh -c 'cd /app/backend && python3 -c "
import os, django
os.environ[\"DJANGO_SETTINGS_MODULE\"] = \"plane.settings.production\"
django.setup()
from plane.license.utils.instance_value import get_email_configuration
print(get_email_configuration())
"'
```

If HOST, USER, PASSWORD, or FROM are empty, configure them:

```bash
docker compose exec -T plane sh -c 'cd /app/backend && python3 -c "
import os, django
os.environ[\"DJANGO_SETTINGS_MODULE\"] = \"plane.settings.production\"
django.setup()
from plane.license.models import InstanceConfiguration
from plane.license.utils.encryption import encrypt_data

updates = {
    \"EMAIL_HOST\": \"smtp.resend.com\",
    \"EMAIL_HOST_USER\": \"resend\",
    \"EMAIL_HOST_PASSWORD\": encrypt_data(\"<resend-api-key>\"),
    \"EMAIL_PORT\": \"587\",
    \"EMAIL_USE_TLS\": \"1\",
    \"EMAIL_USE_SSL\": \"0\",
    \"EMAIL_FROM\": \"plane@internal.bobadilla.tech\",
}
for key, val in updates.items():
    n = InstanceConfiguration.objects.filter(key=key).update(value=val)
    if not n:
        InstanceConfiguration.objects.create(key=key, value=val)
    print(key, \"ok\")
"'
```

Important notes:
- `EMAIL_HOST_PASSWORD` must be stored **encrypted** using `encrypt_data()`.
  Storing plain text will cause `InvalidToken` errors at send time.
- `EMAIL_USE_TLS` must be `"1"` (not `"true"`). The task does a literal
  `== "1"` check.
- The sending domain (`internal.bobadilla.tech`) must be verified in the
  Resend dashboard before emails will go through. DNS propagation can take
  a few hours.

#### GlitchTip SMTP

GlitchTip uses `EMAIL_URL` in `services/glitchtip.env`:

```
EMAIL_URL=smtp://resend:<resend_api_key>@smtp.resend.com:587/?tls=True
DEFAULT_FROM_EMAIL=glitchtip@internal.bobadilla.tech
```

If GlitchTip still uses `consolemail://`, invitation links are written to logs.
Extract and clean wrapped links with:

```bash
docker compose logs --tail=500 glitchtip \
| perl -pe 's/=\n//g; s/=3D/=/g' \
| grep -o 'https://issues\.bobadilla\.tech/(accept|profile/confirm-email)/[^" ]+'
```

### One-Command Recovery

When app services fail due to DB auth drift, startup order, or n8n encryption
key mismatch, run:

```bash
./scripts/recover.sh
```

This script:

- starts core dependencies (`postgres`, `redis`, `rabbitmq`, `minio`),
- waits for PostgreSQL readiness,
- reconciles app roles/databases against `.env` passwords,
- resets only n8n local state to avoid key mismatch loops,
- recreates `n8n`, `glitchtip`, and `caddy`, then starts `plane`.

### Plane Local Snapshot Workaround

If Plane is already working and the upstream image tag is broken, snapshot the
live container with `docker export | docker import` instead of `docker commit`.
`docker commit` inherits the image's JSON-array VOLUME declaration in a form
Docker can't parse, causing:
`invalid mount config for type "volume": invalid mount path: '[/app/data,'`

Use this instead:

```bash
# Capture the entrypoint from the running container
CMD=$(docker inspect internal-tools-plane-1 --format='{{json .Config.Cmd}}')

# Export filesystem and reimport clean (no VOLUME metadata)
docker export internal-tools-plane-1 | docker import \
  --change "CMD $CMD" \
  - plane-aio-community:working

# Point .env at the new local image
sed -i 's#^PLANE_IMAGE=.*#PLANE_IMAGE=plane-aio-community:working#' .env
docker compose up -d --force-recreate plane
```

Use this only to reload Plane env changes without changing Plane's application
version.

### MinIO root password

MinIO stores its root credentials in the data volume on first init. The
`MINIO_ROOT_PASSWORD` in `.env` must match whatever is in the volume — they
can drift if the stack was initialized with a different password.

To find the actual password:
```bash
docker compose exec -T minio env | grep MINIO_ROOT_PASSWORD
```

Then sync `.env`:
```bash
sed -i "s#^MINIO_ROOT_PASSWORD=.*#MINIO_ROOT_PASSWORD=<actual_password>#" .env
```

### MinIO bucket / user missing

If Plane reports image upload errors or the `uploads` bucket is missing, run
minio-init manually (it is idempotent):

```bash
docker compose up --force-recreate minio-init
```

This creates the `uploads` and `glitchtip-files` buckets, sets public-download
policy, and creates the `plane-access` user with readwrite permissions.
If minio-init still fails, check that `MINIO_ROOT_PASSWORD` in `.env` matches
the volume (see above).

### Plane Image Uploads

Plane's `start.sh` hardcodes `USE_MINIO=0` in its own env file, which causes
the storage backend to generate presigned upload URLs pointing to
`http://minio:9000` — an internal address the browser can never reach.

The fix has two parts (both already wired in):

1. **`scripts/patch-plane-settings.py`** runs at container startup and
   comments out the `USE_MINIO=0` line in `start.sh`, keeping `USE_MINIO=1`
   from the container environment.  With `USE_MINIO=1`, the storage backend
   generates presigned POST URLs using `request.get_host()` —
   i.e. `https://tasks.bobadilla.tech/uploads`.

2. **`Caddyfile`** routes `handle /uploads*` on `tasks.bobadilla.tech`
   directly to `minio:9000`, so the browser's upload POST reaches MinIO
   through the same public domain.

If image uploads break again after a Plane image update, check:

```bash
# Confirm USE_MINIO=1 in the gunicorn process
docker compose exec -T plane sh -c 'cat /proc/$(pgrep -f gunicorn | head -1)/environ | tr "\0" "\n" | grep USE_MINIO'

# Confirm the patch ran
docker compose exec -T plane sh -c 'grep "patched" /app/start.sh'

# Confirm Caddy routes /uploads to MinIO (should return XML, not Plane HTML)
curl -s https://tasks.bobadilla.tech/uploads | head -3
```

If USE_MINIO is 0, force-recreate the plane container (the patch runs at
startup):

```bash
docker compose up -d --force-recreate plane
```

### Plane God Mode Access

God Mode (`/god-mode/`) uses a separate `InstanceAdmin` model — not the
regular `is_superuser` / `is_staff` flags. If login fails with
"Authentication failed", add the user as a verified instance admin:

```bash
docker compose exec -T plane sh -c 'cd /app/backend && python3 -c "
import os,django
os.environ[\"DJANGO_SETTINGS_MODULE\"]=\"plane.settings.production\"
django.setup()
from plane.license.models import InstanceAdmin, Instance
from plane.db.models import User
u = User.objects.get(email=\"eliaz@bobadilla.tech\")
inst = Instance.objects.first()
InstanceAdmin.objects.update_or_create(user=u, instance=inst, defaults={\"role\":20,\"is_verified\":True})
print(\"done\")
"'
```

Then log in at `https://tasks.bobadilla.tech/god-mode/` with the regular
Plane account password.

## Mattermost

Mattermost runs at `https://chat.bobadilla.tech` (port 8065, proxied by Caddy).
It uses the shared PostgreSQL (`mattermost_db`) and a local Docker volume for file storage.

### First-Run Setup

On a fresh deploy, visit `https://chat.bobadilla.tech` and complete the setup wizard
to create the admin account. No post-deploy DB commands needed.

### Adding Mattermost DB on an Existing Postgres Volume

Docker init scripts only run on an empty volume. If `postgres_data` already exists,
create the database manually before starting Mattermost:

```bash
MATTERMOST_DB_PASSWORD=$(grep ^MATTERMOST_DB_PASSWORD .env | cut -d= -f2)
docker compose exec -T postgres psql -U postgres_admin -d postgres -c "
  CREATE ROLE mattermost_user LOGIN PASSWORD '$MATTERMOST_DB_PASSWORD';
  CREATE DATABASE mattermost_db OWNER mattermost_user;
  GRANT ALL PRIVILEGES ON DATABASE mattermost_db TO mattermost_user;
"
docker compose up -d mattermost
```

### Rename Plane Workspace Slug

To rename the default workspace slug (e.g. `agency-core` → `core`):

```bash
docker compose exec -T postgres psql -U plane_user -d plane_db -c \
  "UPDATE workspaces SET slug='core', name='Core' WHERE slug='agency-core' RETURNING id, name, slug;"
```

## Fresh Install — Post-Deploy Checklist

After a fresh deploy (new server or wiped volumes), complete these steps once:

1. **Verify the sending domain** in Resend: `internal.bobadilla.tech` must show
   status "Domain verified" before any email will go through.

2. **Configure Plane email in the DB** (see SMTP section above). This is
   required on every fresh Postgres volume because the InstanceConfiguration
   table starts empty and env-var fallbacks are not reliable.

3. **Verify MinIO buckets and user exist**: run `docker compose up
   --force-recreate minio-init` if Plane reports image upload errors on first
   use. This creates the `uploads` bucket and `plane-access` MinIO user.

4. **Mattermost first-run**: visit `https://chat.bobadilla.tech` and complete
   the setup wizard to create the admin account.

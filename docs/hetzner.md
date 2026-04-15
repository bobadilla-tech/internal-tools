# Hetzner Deployment Guide

This guide takes you from a fresh Hetzner Cloud server to a running stack.

## 1. Create the Server

In Hetzner Cloud:

1. Create a new project.
2. Add your SSH key in Security -> SSH Keys.
3. Create a server:
   - Location: closest to your users.
   - Image: Ubuntu 24.04.
   - Type: at least 4 vCPU / 8 GB RAM.
   - Networking: public IPv4 enabled.
4. Optional: attach a Cloud Firewall that allows only TCP 22, 80, and 443.

## 2. Point DNS

Create A records to the server IP:

- `issues.bobadilla.tech`
- `tasks.bobadilla.tech`
- `flows.bobadilla.tech`

Wait for DNS propagation before expecting TLS certificates.

## 3. Bootstrap the Host

Important: paste only the commands below. Do not paste shell prompts like
`root@host:~#` or command output lines.

SSH into the server as root or a sudo user:

```bash
ssh root@<server_ip>
```

Install Docker and Compose plugin:

```bash
apt update
apt install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg
ARCH=$(dpkg --print-architecture)
CODENAME=$(awk -F= '/^VERSION_CODENAME=/{print $2}' /etc/os-release)
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${CODENAME} stable" > /etc/apt/sources.list.d/docker.list
apt update
apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Create a deploy user and grant Docker access:

```bash
id deploy >/dev/null 2>&1 || adduser deploy
usermod -aG sudo deploy
usermod -aG docker deploy
docker --version
docker compose version
```

## 4. Host Firewall (UFW)

```bash
apt install -y ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
ufw status
```

## 5. Upload Project and Configure Env

As the deploy user:

```bash
su - deploy
```

Wait for the prompt to change to `deploy@...` and then run:

```bash
git clone https://github.com/bobadilla-tech/internal-tools
cd internal-tools
cp .env.example .env
cp services/glitchtip.env.example services/glitchtip.env
cp services/plane.env.example services/plane.env
cp services/n8n.env.example services/n8n.env
./scripts/generate-secrets.sh --apply
```

Edit `.env` and service env files if you need custom domains or retention
values. The secret generator synchronizes service credentials automatically.

If you want real user invite/reset emails, configure SMTP before deploy:

For Resend SMTP, use username `resend` and your Resend API key as the SMTP
password.

```bash
# GlitchTip
# Replace consolemail:// with real SMTP
sed -i 's#^EMAIL_URL=.*#EMAIL_URL=smtp://resend:<resend_api_key>@smtp.resend.com:465/?ssl=True#' services/glitchtip.env

# Plane
cat <<'EOF' >> services/plane.env
DEFAULT_FROM_EMAIL=plane@tasks.bobadilla.tech
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.resend.com
EMAIL_PORT=465
EMAIL_HOST_USER=resend
EMAIL_HOST_PASSWORD=<resend_api_key>
EMAIL_USE_TLS=false
EMAIL_USE_SSL=true
EOF
```

Keep SMTP credentials only in server runtime files (`.env`, `services/*.env`).
Do not commit real credentials.

## 6. Deploy

```bash
docker compose pull
docker compose up -d
docker compose ps
```

If you see `password authentication failed` for `glitchtip_user` right after a
fresh install, your PostgreSQL volume was likely initialized with older
credentials. If you have no data to preserve yet, run a clean reset:

```bash
docker compose down -v
docker compose up -d
docker compose ps
```

If you update this repository after the first deploy, recreate Caddy so it picks
up any new environment variables or Caddyfile changes:

```bash
docker compose up -d --force-recreate caddy
docker compose logs --tail=100 caddy
```

If you changed app SMTP/env settings, recreate app containers:

```bash
docker compose up -d --force-recreate glitchtip plane
docker compose ps
```

Check logs:

```bash
docker compose logs -f caddy
docker compose logs -f glitchtip
docker compose logs -f plane
docker compose logs -f n8n
```

Quick email checks:

```bash
docker compose logs --tail=300 glitchtip | rg -i "invite|email|smtp|reset"
docker compose logs --tail=300 plane | rg -i "invite|email|smtp|reset"
```

## 7. First Access

Open:

- `https://issues.bobadilla.tech`
- `https://tasks.bobadilla.tech`
- `https://flows.bobadilla.tech`

## 8. Update Workflow

```bash
cd ~/internal-tools
./scripts/update.sh
```

## Notes

- You do not need an AWS account. GlitchTip and Plane use MinIO in this stack.
- If certificates do not issue, verify DNS, ports 80/443, and firewall rules.

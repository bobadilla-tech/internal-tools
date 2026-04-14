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

- `errors.bobadilla.tech`
- `tasks.bobadilla.tech`
- `flows.bobadilla.tech`

Wait for DNS propagation before expecting TLS certificates.

## 3. Bootstrap the Host

Important: paste only the commands below. Do not paste shell prompts like `root@host:~#` or command output lines.

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
read -rsp "Caddy basic-auth password: " CADDY_PASS; echo
./scripts/generate-secrets.sh "$CADDY_PASS" --apply
unset CADDY_PASS
```

Edit `.env` and service env files if you need custom domains or retention
values.

## 6. Deploy

```bash
docker compose pull
docker compose up -d
docker compose ps
```

Check logs:

```bash
docker compose logs -f caddy
docker compose logs -f glitchtip
docker compose logs -f plane
docker compose logs -f n8n
```

## 7. First Access

Open:

- `https://errors.bobadilla.tech`
- `https://tasks.bobadilla.tech`
- `https://flows.bobadilla.tech`

Use the Caddy basic-auth credentials you set during `generate-secrets.sh`.

## 8. Update Workflow

```bash
cd ~/internal-tools
./scripts/update.sh
```

## Notes

- You do not need an AWS account. GlitchTip and Plane use MinIO in this stack.
- Keep a secure copy of your Caddy password. Only the hash is stored in `.env`.
- If certificates do not issue, verify DNS, ports 80/443, and firewall rules.

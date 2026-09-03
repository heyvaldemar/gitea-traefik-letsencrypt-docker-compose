# Gitea + Traefik + Let's Encrypt — Docker Compose

[![Deployment Verification](https://github.com/heyvaldemar/gitea-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml/badge.svg?branch=main)](https://github.com/heyvaldemar/gitea-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Contents

- [Why this stack?](#why-this-stack)
- [Prerequisites](#prerequisites)
- [Getting started](#getting-started)
- [Features](#features)
  - [Typical use cases](#typical-use-cases)
- [SSH access to repositories](#ssh-access-to-repositories)
- [Supply chain trust](#supply-chain-trust)
- [Production checklist](#production-checklist)
- [Backups](#backups)
- [Testing](#testing)
- [Security Notes](#security-notes)
- [About the maintainer](#about-the-maintainer)

This repository deploys **Gitea** behind **Traefik** with automatic **Let's Encrypt TLS**, backed by **PostgreSQL**, with git-over-SSH routed through a dedicated Traefik TCP entrypoint, a scheduled **backup container** (database + repositories), and companion **restore scripts**. One `docker compose up` away from a self-hosted software forge at `https://your-domain`.

📙 Full narrative installation guide on the blog: [heyvaldemar.com/install-gitea-using-docker-compose/](https://www.heyvaldemar.com/install-gitea-using-docker-compose/).

## Why this stack?

| Need | This stack | Manual install | Kubernetes | Other compose examples |
|------|-----------|----------------|------------|------------------------|
| Ready to deploy in <10 min | ✅ | ❌ hours of setup | ✅ if K8s is already running | Often |
| TLS via Let's Encrypt, auto-renewed | ✅ Traefik ACME built-in | Manual certbot | Via cert-manager | Rare |
| Git-over-SSH through the proxy | ✅ Traefik TCP entrypoint | Manual port juggling | Service/LB config | Rare |
| Admin auto-created on first run | ✅ from env | Setup wizard | Varies | Varies |
| Scheduled DB + repo backups + pruning | ✅ | Manual cron | External | Rare |
| Upstream images pinned by `sha256` digest | ✅ | N/A | Depends | Rare |
| Weekly pin-freshness check in CI | ✅ | N/A | Depends | Rare |
| CI-verified deployment on every push | ✅ healthz answers | N/A | Varies | Rare |
| Credentials via env (never committed) | ✅ | N/A | K8s Secrets | Often committed plaintext |

Four moving parts (Traefik + Gitea + Postgres + backups). No Kubernetes prerequisites, no manual certificate management.

## Prerequisites

Before you start, you need:

- **A Linux server** with a public IP. Tested on Ubuntu 22.04 LTS+ and Debian 12+. Local Mac/Windows works for dev; production is Linux.
- **Docker Engine 24+ and Docker Compose 2.20+.** Quick check: `docker version` and `docker compose version`.
- **A domain you control,** with two `A` records pointing at your server's public IP — one for Gitea (e.g. `gitea.example.com`), one for the Traefik dashboard (e.g. `traefik.gitea.example.com`). DNS must propagate before deploy or the Let's Encrypt TLS-ALPN challenge will fail.
- **Ports 80, 443, and 2222 open** — 2222 carries git-over-SSH (configurable via `GITEA_SHELL_SSH_PORT`).
- **~1 GB free RAM and 1 free CPU** for the running stack, plus disk for repositories and backup retention.

## Getting started

```bash
# 1. Clone
git clone https://github.com/heyvaldemar/gitea-traefik-letsencrypt-docker-compose
cd gitea-traefik-letsencrypt-docker-compose

# 2. Create the two Docker networks the stack expects
docker network create traefik-network
docker network create gitea-network

# 3. Copy the environment template and fill in required values
cp .env.example .env
$EDITOR .env
# ^ Required: GITEA_DB_PASSWORD, GITEA_ADMIN_PASSWORD, GITEA_ADMIN_EMAIL,
#   GITEA_HOSTNAME, GITEA_URL, TRAEFIK_HOSTNAME, TRAEFIK_ACME_EMAIL,
#   TRAEFIK_BASIC_AUTH. See .env.example for generation commands.

# 4. Deploy
docker compose -f gitea-traefik-letsencrypt-docker-compose.yml -p gitea up -d
```

Within a minute `https://${GITEA_HOSTNAME}` serves Gitea with a fresh Let's Encrypt certificate. The admin account from `GITEA_ADMIN_USERNAME` / `GITEA_ADMIN_PASSWORD` is created automatically on first run.

### What success looks like

```bash
# All services healthy:
docker compose -f gitea-traefik-letsencrypt-docker-compose.yml -p gitea ps

# Gitea's health endpoint:
curl -fsS "https://${GITEA_HOSTNAME}/api/healthz"
# Expected: "status": "pass"

# Traefik issued a certificate:
docker compose -p gitea logs traefik | grep -i "adding certificate"

# Clone over SSH (after adding your key in the UI):
git clone ssh://git@${GITEA_HOSTNAME}:2222/<owner>/<repo>.git
```

### Common first-deploy issues

- **Cert issuance fails.** DNS hasn't propagated or port 80 isn't reachable from the internet. Confirm with `dig +short ${GITEA_HOSTNAME}` and `curl -I http://${GITEA_HOSTNAME}` from outside the server.
- **`docker compose up` fails with `set in .env`.** A required variable is empty; the error names it.
- **`network gitea-network not found`.** Step 2 was skipped.
- **SSH clone hangs.** Port 2222 is closed on the firewall, or your remote URL uses port 22 instead of `GITEA_SHELL_SSH_PORT`.

### Apply `.env` or compose-file changes

```bash
docker compose -f gitea-traefik-letsencrypt-docker-compose.yml -p gitea up -d --force-recreate
```

## Features

- **Gitea** latest stable (1.27.3) — repositories, issues, pull requests, actions, packages.
- **PostgreSQL** backing store with healthcheck and start-order dependency.
- **Traefik v3** reverse proxy with automatic HTTP→HTTPS redirect and Let's Encrypt TLS-ALPN certificate issuance.
- **Git-over-SSH via a dedicated Traefik TCP entrypoint** on port 2222 — no host-level SSH conflicts.
- **Bootstrap admin auto-created** from env on first run.
- **Basic-auth protected Traefik dashboard** on a separate hostname.
- **Scheduled backups** of the database (`pg_dump | gzip`) and repository data (`tar.gz`) with retention pruning, plus restore scripts for both.
- **Credentials required at deploy time** — compose fails fast if `.env` is incomplete.

### Typical use cases

- **Self-hosted GitHub alternative** — code on your own hardware, including private mirrors.
- **CI target for homelabs** — Gitea Actions is workflow-compatible with a large part of the GitHub Actions ecosystem.
- **Internal forge for a small team** — lightweight (a fraction of GitLab's footprint) with the features that matter.
- **Air-gapped or compliance-bound development** — data residency without SaaS.

## SSH access to repositories

Git-over-SSH flows through Traefik's TCP entrypoint on `GITEA_SHELL_SSH_PORT` (default 2222). Clone URLs look like:

```bash
git clone ssh://git@gitea.example.com:2222/owner/repo.git
```

Add your public key in Gitea (Settings → SSH / GPG Keys) first. HTTPS clones work on 443 with no extra setup.

## Supply chain trust

This repository is a **deployment template**, not a custom Docker image. It orchestrates three upstream images:

- [`traefik`](https://hub.docker.com/_/traefik) — reverse proxy, Docker Hub official image
- [`gitea/gitea`](https://hub.docker.com/r/gitea/gitea) — Gitea upstream
- [`postgres`](https://hub.docker.com/_/postgres) — PostgreSQL, Docker Hub official image

All three are pinned to `tag@sha256:<digest>` as interpolation defaults in the compose file's `x-images` block. Compose pulls by digest, not by tag — and `git pull` alone delivers the version combination this repository has tested. Setting an `*_IMAGE_TAG` variable in `.env` overrides the default when you deliberately want a different version.

The daily `check-pin-freshness` CI job re-resolves each pinned tag against its registry and compares the pinned Gitea and Traefik versions against the latest upstream releases — any drift fails the run and notifies the maintainer. CI's **Deployment Verification** workflow runs on every push, pull request, and every day at 06:00 UTC. GitHub Actions are pinned by commit SHA; Dependabot keeps those fresh.

## Production checklist

Before exposing this to real users, check every box:

- [ ] **Strong secrets.** `GITEA_DB_PASSWORD` and `GITEA_ADMIN_PASSWORD` at 24+ random characters; regenerate the Traefik dashboard BCrypt hash per deployment.
- [ ] **Disable open registration** unless the forge is meant to be public: Site Administration → Authentication, or set `GITEA__service__DISABLE_REGISTRATION: true` on the gitea service.
- [ ] **Host-mount the backup volumes** for disaster recovery — bind the backup paths to host directories covered by your off-host backup solution.
- [ ] **Verify Let's Encrypt cert issuance** in the Traefik logs on first start.
- [ ] **Know the restore procedure.** Run both restore scripts against a test environment before you need them in production.
- [ ] **Back up before upgrades.** Gitea migrates its schema forward automatically; the way back is a restore.

## Backups

The `backups` container performs a dump → archive → prune → sleep loop: `pg_dump | gzip` of the database, `tar.gz` of the repository data directory, pruning by retention windows, then sleeping `BACKUP_INTERVAL` (default 24h). All knobs are configured via `.env` with compose-level defaults.

Each cycle logs `Database backup OK: <file> (<bytes> bytes)` or `Database backup FAILED` (the same for the data archive where there is one). A failed dump is kept as `<file>.failed` for diagnosis and never overwrites a good backup — grep the log for `FAILED` from your monitoring.

**Verify backups are running:**

```bash
docker compose -p gitea logs backups | tail -5
docker compose -p gitea exec backups sh -c 'ls -la /srv/gitea-postgres/backups/ /srv/gitea-application-data/backups/'
```

**Restore** with the interactive scripts (`chmod +x *.sh` once):

```bash
./gitea-restore-database.sh          # database: stops Gitea, drop/create/restore, starts
./gitea-restore-application-data.sh  # repositories and data directory
```

## Resource limits

Every service carries memory and CPU limits plus reservations as compose-level defaults — the same values CI boots the stack under. Override any of them in `.env` (the knobs and their defaults are listed in `.env.example`, e.g. `TRAEFIK_MEMORY_LIMIT=512m`) and the override survives every `git pull`. If a service is OOM-killed under real load, `docker inspect <container> --format '{{.State.OOMKilled}}'` says so; raise its `_MEMORY_LIMIT` and recreate.

## Container hardening

Every service runs with `security_opt: no-new-privileges:true`, so a process cannot gain privileges through setuid binaries even if it escapes its initial capability set. Infrastructure containers (the reverse proxy, databases, caches, backups) run with `cap_drop: [ALL]` and add back only what their entrypoints need: `NET_BIND_SERVICE` for Traefik to bind :80/:443, `CHOWN`/`SETUID`/`SETGID` (and friends) for database images to own their data directory and drop to their service user. Application containers keep the default capability set on purpose: upstream images assume it, and a wrong guess there is a boot loop in production rather than a hardening win. CI boots the stack under exactly these settings on every push, so what ships is what was tested.

## Testing

The [Deployment Verification](https://github.com/heyvaldemar/gitea-traefik-letsencrypt-docker-compose/actions/workflows/deployment-verification.yml?query=branch%3Amain) workflow runs on every push, pull request, and every day at 06:00 UTC:

1. **Lint** — shellcheck on both restore scripts, actionlint on the workflow.
2. **Trivy scans** of all three pinned images (CRITICAL/HIGH, SARIF to the Security tab).
3. **Pin freshness** (daily/manual) — digest drift plus release-lag checks for Gitea and Traefik.
4. **Deploy-and-test** — boots the full stack with ephemeral credentials and requires `/api/healthz` to answer `pass` through Traefik plus a 200 front page — the shipped configuration must produce a working forge, not just started containers.

A green run is the authoritative proof that the template deploys end-to-end and that its backups restore.

### Backup and restore, proven

`tests/e2e-backup-restore.sh` runs against the live stack and is what CI executes after the HTTPS smoke. The scenario that matters most is the restore roundtrip: insert a marker row, restore the earliest backup, assert the marker is gone — a backup that cannot be restored fails the build. Run it yourself against a running deployment with short intervals in `.env` (`BACKUP_INIT_SLEEP=15s`, `BACKUP_INTERVAL=60s`):

```bash
chmod +x tests/e2e-backup-restore.sh
./tests/e2e-backup-restore.sh
```

It stops the database container briefly to prove failure detection — run it on a staging copy, not on production.

## Security Notes

- Credentials are read from `.env` at deploy time; `.env` is gitignored and compose fails fast on missing required variables.
- **Pre-rotation advisory.** Releases before v1.0.0 (2026-08-31) shipped a tracked `.env` with generated-looking passwords. Rotate `GITEA_DB_PASSWORD` and `GITEA_ADMIN_PASSWORD` if your deployment reused them.
- The database listens only on the internal network.
- Upstream image digests are pinned; the daily freshness job flags drift loudly.

---

## About the maintainer

<div align="center">

**Maintained by [Vladimir Mikhalev](https://github.com/heyvaldemar)** — Docker Captain · IBM Champion · AWS Community Builder

[YouTube](https://www.youtube.com/channel/UCf85kQ0u1sYTTTyKVpxrlyQ?sub_confirmation=1) · [Blog](https://heyvaldemar.com) · [LinkedIn](https://www.linkedin.com/in/heyvaldemar/)

</div>

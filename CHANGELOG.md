# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_(no unreleased changes yet)_

## [1.0.0] - 2026-08-31

First semver release. Brings this template to the fleet standard established
in [keycloak-traefik-letsencrypt-docker-compose](https://github.com/heyvaldemar/keycloak-traefik-letsencrypt-docker-compose)
v1.2.0.

### Security

- **Credentials untracked from git.** The repository previously shipped a
  tracked `.env` with generated-looking passwords published on GitHub.
  `.env` is now gitignored; `.env.example` ships `change_me_*` placeholders
  with generation commands, and the compose file fails fast via `${VAR:?}`
  when required secrets are unset.
- **Gitea bumped 1.25 → 1.27.3** (`gitea/gitea:1.27.3@sha256:87a67ee0…`).
- **Traefik bumped 3.2 → 3.7** — Traefik 3.2's Docker client cannot talk
  to Docker Engine 29 (provider retry loop, silent 404s on current hosts).
- **All three images pinned by `tag@sha256:digest`** (`postgres:15`
  digest-pinned; PostgreSQL major deliberately unchanged).

### Changed

- **Image pins live in the compose file as interpolation defaults**
  (`x-images` block): `git pull` alone delivers the tested version
  combination; `.env` carries only secrets and deliberate overrides.
- Operational variables now have compose-level defaults — the minimal
  `.env` is secrets and hostnames only.
- Backup-loop variables escaped (`$$VAR`) for runtime resolution.

### Added

- **Deployment Verification workflow**: shellcheck + actionlint; Trivy
  scans of all three pinned images; weekly `check-pin-freshness` (digest
  drift + Gitea and Traefik release lag); deploy-and-test that stands up
  the full stack with ephemeral credentials and requires `/api/healthz`
  to answer through Traefik.

### Fixed

- Shellcheck findings in both restore scripts.

[Unreleased]: https://github.com/heyvaldemar/gitea-traefik-letsencrypt-docker-compose/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/heyvaldemar/gitea-traefik-letsencrypt-docker-compose/releases/tag/v1.0.0

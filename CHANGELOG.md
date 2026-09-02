# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_(no unreleased changes yet)_

## [1.3.0] - 2026-09-02

### Added

- **Resource limits on every service, as `.env`-overridable defaults.**
  Each service now carries memory and CPU limits plus reservations
  (`<SERVICE>_MEMORY_LIMIT`, `_CPU_LIMIT`, `_MEMORY_RESERVATION`,
  `_CPU_RESERVATION`, defaults listed in `.env.example`). Set any of
  them in `.env` and the override survives every `git pull`. The
  defaults are what CI boots the stack under, so they are known to be
  enough for a fresh install; raise a limit if a service is OOM-killed
  under your real load (`docker inspect` shows `OOMKilled=true`).

## [1.2.0] - 2026-09-02

### Fixed

- **A file changing while the data archive is written no longer marks
  the backup as failed.** GNU `tar` exits 1 when a live application
  touched a file mid-read; the archive is complete and usable. The loop
  now treats exit 1 as success (noting it in the log line) and only a
  real `tar` failure (exit 2) produces `FAILED`. CI's archive check now
  reads the file name from the `backup OK` log line instead of racing an
  archive that may still be being written.

### Added

- **`tests/e2e-backup-restore.sh`** — seven end-to-end scenarios against
  the live stack, run by CI on every push and by you locally: the
  required-variable guard fires, a backup is produced, it is a readable
  archive with real dump content (and a readable data `tar.gz` where the
  stack has one), a database outage is reported as `FAILED`, **restore
  genuinely replaces database state** (a marker row inserted after the
  baseline backup is gone after restoring it), and pruning removes only
  old files.

## [1.1.0] - 2026-09-02

### Fixed

- **A failed database dump no longer produces a silent, corrupt backup.**
  The old loop piped the dump into `gzip` and only checked `gzip`'s exit
  status, so a dump that failed halfway (database down, wrong password,
  disk full) still left a small `.gz` that looked like a backup. The loop
  now runs with `pipefail`, logs `Database backup OK: <file> (<bytes>
  bytes)` or `Database backup FAILED` per cycle, keeps a failed dump as
  `<file>.failed` for diagnosis, and prunes only its own files. Retention
  set to `0` disables pruning instead of deleting everything.

### Added

- CI now waits for the first backup cycle and proves the produced
  archive is readable and contains a real dump header (plus a readable
  `tar.gz` for the data backup where the stack has one).

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

[Unreleased]: https://github.com/heyvaldemar/gitea-traefik-letsencrypt-docker-compose/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/heyvaldemar/gitea-traefik-letsencrypt-docker-compose/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/heyvaldemar/gitea-traefik-letsencrypt-docker-compose/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/heyvaldemar/gitea-traefik-letsencrypt-docker-compose/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/heyvaldemar/gitea-traefik-letsencrypt-docker-compose/releases/tag/v1.0.0

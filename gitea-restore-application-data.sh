#!/usr/bin/env bash
# gitea-restore-application-data.sh [backup-file-name]
#
# Replaces Gitea's application data with one of the archives the backups
# service wrote.
#
#   ./gitea-restore-application-data.sh               list and ask
#   ./gitea-restore-application-data.sh <file-name>   restore that one
#
# EVERY PATH, NAME AND CREDENTIAL COMES FROM THE RUNNING BACKUPS CONTAINER.
# The previous version cleared /bitnami/gitea/, a Bitnami path this stack does
# not have, then unpacked the archive over the live /data. Files created after
# the backup survived the restore: it merged, it did not restore.
# The backup loop reads its own environment, so this reads the same one, and
# the two cannot disagree.
#
# CI runs this exact file against a marker written after the backup it
# restores, and requires the marker to be gone.
#
# Set COMPOSE_PROJECT_NAME if the stack was started with a -p other than gitea.
set -Eeuo pipefail

PROJECT="${COMPOSE_PROJECT_NAME:-gitea}"
APP_SERVICE="gitea"

cid() {  # the container of one compose service in this project
  docker ps -aq --filter "label=com.docker.compose.project=$PROJECT" \
    --filter "label=com.docker.compose.service=$1" | head -n 1
}
APP="$(cid "$APP_SERVICE")"; BKP="$(cid backups)"
[ -n "$BKP" ] || { echo "error: no backups container in compose project '$PROJECT' (set COMPOSE_PROJECT_NAME)" >&2; exit 1; }
[ -n "$APP" ] || { echo "error: no $APP_SERVICE container in compose project '$PROJECT'" >&2; exit 1; }
[ "$(docker inspect -f '{{.State.Running}}' "$BKP")" = true ] || { echo "error: the backups container is not running" >&2; exit 1; }

env_of() { docker exec "$BKP" printenv "$1"; }
DIR="$(env_of DATA_BACKUPS_PATH)"; NAME="$(env_of DATA_BACKUP_NAME)"; DATA="$(env_of DATA_PATH)"
case "$DATA" in ""|/) echo "error: DATA_PATH is '$DATA'; refusing to clear it" >&2; exit 1 ;; esac

SELECTED="${1:-}"
if [ -z "$SELECTED" ]; then
  echo "Application data backups in $DIR:"
  docker exec "$BKP" sh -c "ls -1 '$DIR' | grep -E '^$NAME-.*\\.tar\\.gz\$'" || { echo "  none found" >&2; exit 1; }
  read -r -p "File name to restore: " SELECTED
fi
case "$SELECTED" in ""|*/*) echo "error: give a file name from the list, not a path" >&2; exit 1 ;; esac
docker exec "$BKP" tar -tzf "$DIR/$SELECTED" >/dev/null \
  || { echo "error: $DIR/$SELECTED is missing or does not open; nothing was changed" >&2; exit 1; }

echo "Stopping $APP_SERVICE so nothing writes while its data is replaced"
docker stop "$APP" >/dev/null
restart() { docker start "$APP" >/dev/null && echo "Started $APP_SERVICE"; }
trap 'restart' EXIT
echo "Restoring $SELECTED"
# The archive holds the data directory relative to / (the loop writes it that
# way), so it is extracted at /; what was there first is removed so files that
# did not exist at backup time do not survive the restore.
if ! docker exec "$BKP" sh -c "set -eu
    find '$DATA' -mindepth 1 -delete
    tar -xzpf '$DIR/$SELECTED' -C /"; then
  echo "error: the restore failed part-way; $DATA may be incomplete. Restore another archive before using Gitea." >&2
  exit 1
fi
echo "Restored $SELECTED into $DATA"

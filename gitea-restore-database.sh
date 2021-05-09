#!/bin/bash

GITEA_CONTAINER=$(docker ps -aqf "name=gitea_gitea")
GITEA_BACKUPS_CONTAINER=$(docker ps -aqf "name=gitea_backups")

echo "--> All available database backups:"

for entry in $(docker container exec -it $GITEA_BACKUPS_CONTAINER sh -c "ls /srv/gitea-postgres/backups/")
do
  echo "$entry"
done

echo "--> Copy and paste the backup name from the list above to restore database and press [ENTER]
--> Example: gitea-postgres-backup-YYYY-MM-DD_hh-mm.gz"
echo -n "--> "

read SELECTED_DATABASE_BACKUP

echo "--> $SELECTED_DATABASE_BACKUP was selected"

echo "--> Stopping service..."
docker stop $GITEA_CONTAINER

echo "--> Restoring database..."
docker exec -it $GITEA_BACKUPS_CONTAINER sh -c 'PGPASSWORD="$(echo $POSTGRES_PASSWORD)" dropdb -h postgres -p 5432 giteadb -U giteadbuser \
&& PGPASSWORD="$(echo $POSTGRES_PASSWORD)" createdb -h postgres -p 5432 giteadb -U giteadbuser \
&& PGPASSWORD="$(echo $POSTGRES_PASSWORD)" gunzip -c /srv/gitea-postgres/backups/'$SELECTED_DATABASE_BACKUP' | PGPASSWORD=$(echo $POSTGRES_PASSWORD) psql -h postgres -p 5432 giteadb -U giteadbuser'
echo "--> Database recovery completed..."

echo "--> Starting service..."
docker start $GITEA_CONTAINER

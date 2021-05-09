# Gitea with Let's Encrypt in a Docker Compose

Install the Docker Engine by following the official guide: https://docs.docker.com/engine/install/

Install the Docker Compose by following the official guide: https://docs.docker.com/compose/install/

Run `gitea-restore-application-data.sh` to restore application data if needed.

Run `gitea-restore-database.sh` to restore database if needed.

Deploy Gitea server with a Docker Compose using the command:

`docker-compose -f gitea-traefik-letsencrypt-docker-compose.yml -p gitea up -d`

#!/usr/bin/env bash
set -x
set -eo pipefail

# Check for custom parameter settings, otherwise use defaults
DB_PORT=${POSTGRES_PORT:=5432}
SUPERUSER=${SUPERUSER:=postgres}
SUPERUSER_PWD=${SUPERUSER_PWD:=postgres}
APP_USER=${APP_USER:=app}
APP_USER_PWD=${APP_USER_PWD:=secret}
APP_DB_NAME=${APP_DB_NAME:=newsletter}

# Launch postgres using Docker
CONTAINER_NAME="postgres"
docker run \
  --env POSTGRES_USER=${SUPERUSER} \
  --env POSTGRES_PASSWORD=${SUPERUSER_PWD} \
  --health-cmd="pg_isready -U ${SUPERUSER} || exit 1" \
  --health-interval=1s \
  --health-timeout=5s \
  --health-retries=5 \
  --publish "${DB_PORT}":5432 \
  --detach \
  --name "${CONTAINER_NAME}" \
  postgres -N 1000
# ^ Increased maximum number of connections for testing purposes
#sleep 30

# Wait for Postgres to be ready to accept connections
until [ \
  "$(docker inspect -f "{{.State.Health.Status}}" ${CONTAINER_NAME})" == \
  "healthy" \
]; do
    >&2 echo "Postgres is unavailable - waiting..."
    sleep 1
done

>&2 echo "Postgres is up and running on port ${DB_PORT}!"

# Create the user
CREATE_QUERY="CREATE USER ${APP_USER} WITH PASSWORD '${APP_USER_PWD}';"
docker exec -it "${CONTAINER_NAME}" psql -U "${SUPERUSER}" -c "${CREATE_QUERY}"

# Grant db-creation permissions to the user
GRANT_QUERY="ALTER USER ${APP_USER} CREATEDB;"
docker exec -it "${CONTAINER_NAME}" psql -U "${SUPERUSER}" -c "${GRANT_QUERY}"

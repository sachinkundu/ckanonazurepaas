#!/bin/sh
set -e

# URL for the primary database, in the format expected by sqlalchemy (required
# unless linked to a container called 'db')
: ${CKAN_SQLALCHEMY_URL:=}
# URL for solr (required unless linked to a container called 'solr')
: ${CKAN_SOLR_URL:=}
# URL for redis (required unless linked to a container called 'redis')
: ${CKAN_REDIS_URL:=}
# URL for datapusher (required unless linked to a container called 'datapusher')
: ${CKAN_DATAPUSHER_URL:=}

CONFIG="${CKAN_CONFIG}/production.ini"

abort () {
  echo "$@" >&2
  exit 1
}

set_environment () {
  export CKAN_SITE_ID=${CKAN_SITE_ID}
  export CKAN_SITE_URL=${CKAN_SITE_URL}
  export CKAN_SQLALCHEMY_URL=${CKAN_SQLALCHEMY_URL}
  export CKAN_SOLR_URL=${CKAN_SOLR_URL}
  export CKAN_REDIS_URL=${CKAN_REDIS_URL}
  export CKAN_STORAGE_PATH=/var/lib/ckan
  export CKAN_DATAPUSHER_URL=${CKAN_DATAPUSHER_URL}
  export CKAN_DATASTORE_WRITE_URL=${CKAN_DATASTORE_WRITE_URL}
  export CKAN_DATASTORE_READ_URL=${CKAN_DATASTORE_READ_URL}
  export CKAN_SMTP_SERVER=${CKAN_SMTP_SERVER}
  export CKAN_SMTP_STARTTLS=${CKAN_SMTP_STARTTLS}
  export CKAN_SMTP_USER=${CKAN_SMTP_USER}
  export CKAN_SMTP_PASSWORD=${CKAN_SMTP_PASSWORD}
  export CKAN_SMTP_MAIL_FROM=${CKAN_SMTP_MAIL_FROM}
  export CKAN_MAX_UPLOAD_SIZE_MB=${CKAN_MAX_UPLOAD_SIZE_MB}
  export CKAN_POSTGRES_HOST=${CKAN_POSTGRES_HOST}
  export CKAN_POSTGRES_USER=${CKAN_POSTGRES_USER}

  export CKAN_HOME=/home/ckan
  export CKAN_VENV=/usr/lib/ckan/venv
  export CKAN_CONFIG=/etc/ckan
  export CKAN_STORAGE_PATH=/var/lib/ckan
}

copy_files () {
  mkdir -p $CKAN_HOME
  chown -R ckan:ckan $CKAN_HOME $CKAN_VENV $CKAN_CONFIG $CKAN_STORAGE_PATH
  cp -rf $CKAN_VENV/src/ckan/ckan/config/who.ini $CKAN_CONFIG/who.ini
}

write_config () {
  echo "Generating config at ${CONFIG}..."
  ckan generate config "$CONFIG"
}

create_sysadmin_user () {
  echo "Checking if sysadmin user ${CKAN_SYSADMIN_USERNAME} exists..."
  user=$(ckan -c "$CONFIG" user show "$CKAN_SYSADMIN_USERNAME")
  not_found="User: None"

  if [ "$user" != "$not_found" ]; then
    echo "User ${CKAN_SYSADMIN_USERNAME} already exists."
  else
    echo "Creating user ${CKAN_SYSADMIN_USERNAME}..."
    ckan -c "$CONFIG" user add "$CKAN_SYSADMIN_USERNAME" email="$CKAN_SYSADMIN_EMAIL" password="$CKAN_SYSADMIN_PASSWORD"
  fi

  echo "Promoting user ${CKAN_SYSADMIN_USERNAME} to sysadmin..."
  ckan -c "$CONFIG" sysadmin add "$CKAN_SYSADMIN_USERNAME"
}

# Wait for PostgreSQL
while ! pg_isready -h ${CKAN_POSTGRES_HOST} -U ${CKAN_POSTGRES_USER}; do
  sleep 1;
done

# If we don't already have a config file, bootstrap
if [ ! -e "$CONFIG" ]; then
  write_config
fi

# Get or create CKAN_SQLALCHEMY_URL
if [ -z "$CKAN_SQLALCHEMY_URL" ]; then
  abort "ERROR: no CKAN_SQLALCHEMY_URL specified in docker-compose.yml"
fi

if [ -z "$CKAN_SOLR_URL" ]; then
    abort "ERROR: no CKAN_SOLR_URL specified in docker-compose.yml"
fi

if [ -z "$CKAN_REDIS_URL" ]; then
    abort "ERROR: no CKAN_REDIS_URL specified in docker-compose.yml"
fi

if [ -z "$CKAN_DATAPUSHER_URL" ]; then
    abort "ERROR: no CKAN_DATAPUSHER_URL specified in docker-compose.yml"
fi

if [ -z "$CKAN_SYSADMIN_USERNAME" ]; then
    abort "ERROR: no CKAN_SYSADMIN_USERNAME specified"
fi

if [ -z "$CKAN_SYSADMIN_PASSWORD" ]; then
    abort "ERROR: no CKAN_SYSADMIN_PASSWORD specified"
fi

if [ -z "$CKAN_SYSADMIN_EMAIL" ]; then
    abort "ERROR: no CKAN_SYSADMIN_EMAIL specified"
fi

set_environment
copy_files
ckan --config "$CONFIG" db init
create_sysadmin_user
exec "$@"
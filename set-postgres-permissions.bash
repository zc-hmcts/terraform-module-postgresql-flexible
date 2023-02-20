#!/usr/bin/env bash
set -evx

echo ${DB_HOST_NAME}
echo ${DB_USER}
echo ${DB_READER_USER}
echo ${DB_NAME}

whoami
pwd
env

GET 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/' HTTP/1.1 Metadata: true

az ad signed-in-user show --query objectId -o tsv

export AZURE_CONFIG_DIR=~/.azure-db-manager

# cat ~/.azure-db-manager

az login --identity --verbose

# shellcheck disable=SC2155
export PGPASSWORD=$(az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv)

SQL_COMMAND_POSTGRES="
DO
\$do\$
BEGIN
   IF NOT EXISTS (
      SELECT FROM pg_catalog.pg_roles  -- SELECT list can be empty for this
      WHERE rolname = '${DB_READER_USER}') THEN

      PERFORM pgaadauth_create_principal('${DB_READER_USER}', false, false);
      
   END IF;
END
\$do\$;

"

## Delay until DB DNS and propagated 
COUNT=0;
MAX=10;
while true; do
   ping -c 1 $DB_HOST_NAME &>/dev/null
   if [[ $? -eq 0 ]]; then
      break
   fi
   if [[ $COUNT -eq $MAX ]]; then
      break
   else
      COUNT=$[$COUNT+1]
   fi
   sleep 5
done

psql "sslmode=require host=${DB_HOST_NAME} port=5432 dbname=postgres user=${DB_USER}" -c "${SQL_COMMAND_POSTGRES}"

SQL_COMMAND="

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO PUBLIC;
REVOKE CREATE ON SCHEMA public FROM public;
GRANT USAGE ON SCHEMA public TO \"${DB_READER_USER}\";
GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"${DB_READER_USER}\";

"

psql "sslmode=require host=${DB_HOST_NAME} port=5432 dbname=${DB_NAME} user=${DB_USER}" -c "${SQL_COMMAND}"


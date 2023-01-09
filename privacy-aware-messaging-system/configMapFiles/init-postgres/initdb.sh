#/usr/bin/bash


SLEEPING_TIME=120

echo "Initializing postgres"
echo "Sleeping for ${SLEEPING_TIME} seconds to be certain the service is up"
sleep ${SLEEPING_TIME}

echo "flyway -user=${USERNAME} -password=${PASSWORD} -url=${DB_URL} -placeholders.schema_name=${schema_name} -createSchemas=true -schemas=${schema_name} migrate"
flyway -user=${USERNAME} -password=${PASSWORD} -url=${DB_URL} -placeholders.schema_name=${schema_name} -createSchemas=true -schemas=${schema_name} migrate
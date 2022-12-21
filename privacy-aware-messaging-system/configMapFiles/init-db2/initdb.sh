#/usr/bin/bash


sleep 600  # assume that DB2 is up and running
flyway -url=${DB_URL} -user=${USERNAME} -password=${PASSWORD} -placeholders.schema_name=${schema} migrate
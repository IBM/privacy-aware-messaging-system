FROM --platform=amd64 flyway/flyway:9.0.4

COPY ./driver/* /flyway/jars/

COPY ./db2-schema/* /flyway/sql/

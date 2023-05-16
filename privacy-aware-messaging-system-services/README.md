# Privacy Aware Messaging System (PAMS) - services

This repository contains the code to build and test PAMS. It provides a local Docker-based environment for testing the system on a single host.

There are a number of steps to take prior to running the tests.
1. Buld the PAMS Docker image.
2. Bring up a local environment.
3. Start the PAMS container and run the test.

## Build

Run the ./build.sh script.

## Local Environment

As the messaging system is based on RabbitMQ, we need an admin user for the RabbitMQ management console. This is specified in the scripts/dev-environment.txt file, variable BROKER_ADMIN_USER. You can leave the user as the default, and/or provide a password.

The local environment is comprised of 3 Docker images, one for object storage (Minio/S3), one for a database (PostgresSQL/DB2) and one for RabbitMQ.

To start the local environment:

```
cd scripts
./run-local-env.sh
```

This will do the following:
1. Download the appropriate Docker images.
2. Start Minio/S3 with the configuration provided in s3.txt.
3. Start PostgresSQL with the configuration provided in pg.txt.
4. Configure PostgresSQL with a database schema.
5. Start RabbitMQ with the configuration provided in rabbitmq.txt.
6. Configure RabbitMQ by creating queues and the default user from rabbitmq.txt, variable BROKER_USER.

# Run the example

First, we need to start the PAMS container that was built by the build.sh script.

```
./start_pams.sh
```

Then we can run the example:

```
pip install -r requirements-dev.txt
python -m examples.sample --credentials=./local.json
```


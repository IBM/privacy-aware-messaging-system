# Privacy Aware Messaging System (PAMS)

## Introduction

This repository contains  helm chart and associated services for the creation of the cloud components required by [IBM-FL](https://github.com/IBM/federated-learning-lib) to execute in a pubsub system, as per [example1](https://github.com/IBM/federated-learning-lib/blob/main/examples/pubsub_task.py), [example2](https://github.com/IBM/federated-learning-lib/blob/main/examples/pubsub_register.py), and [example3](https://github.com/IBM/federated-learning-lib/blob/main/examples/pubsub_deregister.py).

These services can also be used to provide a safer communication infrastructure for other scenarios where parties require to communicate in a private manner using [pycloudmessanger](https://github.com/IBM/pycloudmessenger).

## Requirements
* `Docker`
* `Helm version >= 3`
* `Minikube version >= 1.26`

### Setup (on minikube)

1. Install minikube:
  * OS X: `brew install minikube`
  * Linux: XXXX

2. Install helm
  * OS X: `brew install helm`
  * Linux: XXXX
  * Windows: XXXX

3. Start minikube
  `$ minikube start`

## Install Chart

Install the chart using the following command:

```bash
helm install -f myvalues.yaml funny-test ./pams
```

where:
- `funny-test` is the release name, it can be anything that makes the current installation unique within the target system
- `myvalues.yaml` is a (optional) file that contains the overload of specific default values.

An example of content of `myvalues.yaml` is as follows.
Note that the values specified in the dictionary at address `utility.registryCredentials` in `myvalues.yaml` need to be updated according to the user's artifactory credentials, thus replacing the placeholders `EMAIL` and `KEY` with the appropriate values as specified in the Artifactory website.

```yaml
# Docker registry
docker:
  registry:
    name: ""
    username: ""
    password: ""
  timezone: "UTC"
# Database configuration
utility:
  db:
    imageName: "res-drl-docker-local.artifactory.swg-devops.com/pams-utility"
    imageTag: "postgres"
  registryCredentials:
    registry: res-drl-docker-local.artifactory.swg-devops.com
    username: EMAIL
    password: KEY
    email: EMAIL
service:
  imageName: "res-drl-docker-local.artifactory.swg-devops.com/pubsub-backend"
db:
  type: "postgres"
  name: "MYDATABASE"
  imageName: "postgres"
  imageTag: "14.4-alpine"
  imagePullPolicy: "IfNotPresent"
  replicaCount: 1
  restartPolicy: "Always"
  host: null
  port: 5432
  protocol: "http"
  schema_name: "MYSCHEMA"
  auth:
    username: "username"
    password: "password"
  persistence:
    size: 2Gi
rabbitmq:
  external: false
  auth:
    username: "username"
    password: "password"
# S3/COS configuration
s3:
  auth:
    username: "username"
    password: "password"
```

## Notes

* When running in minikube on Apple M1 and if the desired DB is DB2, please follow these steps prior to installation:
```bash
eval $(minikube docker-env)
docker pull ibmcom/db2:11.5.7.0a --platform amd64
```

These commands will configure docker to use minikube docker environment, and retrieve the `amd64` version of the DB2 image.
After that, minikube will not attempt to fetch the image from DockerHub since it already have one with the correct tag name in its local registry.


## DEBUG INSTRUCTION

### Setup Backend Cluster
* Start your docker client and minikube: `minikube start`
* Build a local docker utility image (temporary hack while we finish optimizing the setup)
    * Tell your local docker installation to use minikube as docker engine: `eval $(minikube docker-env)`
    * In `<ROOT_DIR>/utils` run `docker build -t pams-backend-utility:postgres -f Dockerfile.postgres .`
* Now lets build the back end. In `<ROOT_DIR>`:
    * Install all kubernetes modules: `helm install pams ./pams`
    * Check that all minikube modules status are set to `Running`:   `kubectl get all`

### Setup Python Module
* In `<ROOT_DIR>/pams-services/` run:
* `pipenv install`
* `pipenv install --dev`

* Lets make sure everything's running fine
* `pipenv shell`
* `pytest`

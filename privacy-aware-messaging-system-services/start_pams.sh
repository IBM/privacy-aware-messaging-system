#!/usr/bin/env bash
#Author: Mark Purcell (markpurcell@ie.ibm.com)

image=pams
source scripts/make_env.sh ./env.txt
#set -a; source env.txt; set +a
#python -m pams
#exit 1

#If a container is running, kill it
container=`docker ps -a | grep "$image" | cut -f1 -d' '`
if [ ! -z "$container" ]; then
  docker rm -f $container
fi

docker run \
  --name $image --restart=always --detach --privileged=true \
  --env-file ./env.txt \
  $image


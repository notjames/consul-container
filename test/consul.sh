#!/bin/sh
# 
# outlined: https://hub.docker.com/r/progrium/consul/

master_node_ip()
{
  docker inspect -f '{{.NetworkSettings.IPAddress}}' node1
}

start_image()
{
  n=$1
  img_name=$2
  join_ip=$(master_node_ip)

  if [[ -z "$join_ip" ]]
  then
    echo >&2 "Unable to determine master node IP address. Quitting"
    return 5
  fi

  if [[ $node == 1 ]]
  then
    docker run -d --name node$n -h node$n $img_name -server -bootstrap-expect 3
  else
    docker run -d --name node$n -h node$n $img_name -server -join $join_ip
  fi
}

[[ -z "$1" ]] && \
  {
    echo >&2 "No parameters passed from caller. Need docker image name:tag.id"
    exit 5
  }

img_name=$1

for n in {1..3}
do
  start_image $img_name
done

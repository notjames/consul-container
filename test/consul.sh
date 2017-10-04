#!/bin/sh
# 
# outlined: https://hub.docker.com/r/progrium/consul/

master_node_ip()
{
  docker inspect -f '{{.NetworkSettings.IPAddress}}' server1
}

start_images()
{
  [ -z "$1" ] && \
  {
    echo >&2 "usage: start_image image_name"
    return 10
  }

  img_name=$1

  for n in $(seq 1 3)
  do
    [ $n = 1 ] && node_name=server || node_name=node

    docker kill $node_name$n >/dev/null 2>&1
    docker rm $node_name$n > /dev/null 2>&1

    if [ $n = 1 ]
    then
      docker run -d --name server$n -h server$n $img_name agent -dev -bind 0.0.0.0
      join_ip=$(master_node_ip)
    else
      if [ -z "$join_ip" ]
      then
        echo >&2 "Unable to determine master node IP address. Quitting"
        return 5
      fi

      docker run -d --name node$n -h node$n $img_name agent -dev -bind 0.0.0.0 -join $join_ip
    fi
  done
}

show_container_logs()
{
  for c in $(seq 1 3)
  do
    [ $c = 1 ] && node_name=server || node_name=node

    docker logs $node_name$c
    echo "-----------"
  done
}

[ -z "$1" ] && \
  {
    echo >&2 "No parameters passed from caller. Need docker image name:tag.id"
    exit 5
  }

img_name=$1

if ! start_images $img_name
then
  exit $?
fi

n_agents="$(docker ps | grep -Ec 'server1|node[23]')"

if [ -n "$n_agents" -a "$n_agents" = 3 ]
then
  if docker exec -t server1 consul members | grep -c fail
  then
    echo >&2 "FAIL: quorum not achieved. Please investigate"
    show_container_logs
    exit 1
  else
    echo "SUCCESS: qourum achieved."
    exit 0
  fi
else
  echo >&2 "FAIL: there should be three agents running, but there is/are only $n_agents."
  show_container_logs
  exit 2
fi

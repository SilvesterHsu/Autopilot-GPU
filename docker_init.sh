#!/bin/bash
set -e

DOCKER_REPO=silvesterhsu/autopilot-gpu
VERSION=latest
IMG=${DOCKER_REPO}:$VERSION
SSH_PORT=8022

function error() {
  (>&2 printf "[${RED}ERROR${NO_COLOR}] $*")
}

function ok() {
  (>&2 printf "[\e[32m\e[1m OK \e[0m] $*")
}

function scan_port() {
  read lower_port upper_port < /proc/sys/net/ipv4/ip_local_port_range
  init_port=8022
  for ((port=$init_port; port<=$upper_port; port++)) do
    (echo >/dev/tcp/localhost/$port)> /dev/null 2>&1 || break
  done
  SSH_PORT=${port}
}

function main() {
  # PROJECT_PATH=$(cd "$(dirname "$0")";pwd)
  PROJECT_PATH=$(pwd)
  PROJECT_NAME="${PROJECT_PATH##*/}"
  PROJECT_DEV="develop_${PROJECT_NAME}_${USER}"

  (docker stop ${PROJECT_DEV} 1>/dev/null && docker rm -f ${PROJECT_DEV} 1>/dev/null) || true

  USER_ID=$(id -u)
  GRP=$(id -g -n)
  GRP_ID=$(id -g)
  DOCKER_HOME="/home/$USER"

  scan_port
  docker run -it \
            -d \
            -e USER=$USER \
            -e DOCKER_USER_ID=$USER_ID \
            -e DOCKER_GRP=$GRP \
            -e DOCKER_GRP_ID=$GRP_ID \
            -e DOCKER_HOME=$DOCKER_HOME \
            -e SSH_PORT=$SSH_PORT \
            -v ${PROJECT_PATH}:/workspace \
            -v /etc/passwd:/etc/passwd:ro \
            -v /etc/group:/etc/group:ro \
            -v /etc/localtime:/etc/localtime:ro \
            --gpus all \
            --ipc host \
            --security-opt seccomp=unconfined \
            --shm-size=4G \
            --net host \
            --restart always \
            --name ${PROJECT_DEV} \
            $IMG \
            /bin/bash

  docker exec $PROJECT_DEV bash -c 'mkdir -p $DOCKER_HOME \
    && touch $DOCKER_HOME/.profile \
    && chown -R $DOCKER_USER_ID:$DOCKER_GRP_ID $DOCKER_HOME'

  docker cp ${DOCKER_HOME}/.ssh/authorized_keys ${PROJECT_DEV}:/root/.ssh/authorized_keys
  docker exec $PROJECT_DEV bash -c 'sed -i "s/#Port 22/Port ${SSH_PORT}/" /etc/ssh/sshd_config \
    && sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config \
    && sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config \
    && chmod 600 /root/.ssh/authorized_keys \
    && chown root:root /root/.ssh/authorized_keys \
    && service ssh start'

  if [ $? -ne 0 ];then
    error "Failed to start docker container \"${PROJECT_DEV}\" based on image: $IMG"
    exit 1
  fi

  ok "Finished setting up docker container \"${PROJECT_DEV}\" environment.\n \
      Now you can enter with: bash docker_run.sh\n \
      Or connect with ssh -p ${SSH_PORT} root@localhost\n"
  ok "Enjoy!\n"
}

main "$@"

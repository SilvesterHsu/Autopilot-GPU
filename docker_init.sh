#!/bin/bash
set -e

DOCKER_REPO=silvesterhsu/autopilot-gpu
VERSION=latest
IMG=${DOCKER_REPO}:$VERSION
SSH_PORT=8023

function error() {
  (>&2 printf "[${RED}ERROR${NO_COLOR}] $*")
}

function ok() {
  (>&2 printf "[\e[32m\e[1m OK \e[0m] $*")
}

function main() {
  CUDA_DEV="develop_cuda_${USER}"

  (docker stop ${CUDA_DEV} 1>/dev/null && docker rm -f ${CUDA_DEV} 1>/dev/null) || true

  USER_ID=$(id -u)
  GRP=$(id -g -n)
  GRP_ID=$(id -g)
  DOCKER_HOME="/home/$USER"

  docker run -it \
            -d \
            -e USER=$USER \
            -e DOCKER_USER_ID=$USER_ID \
            -e DOCKER_GRP=$GRP \
            -e DOCKER_GRP_ID=$GRP_ID \
            -e DOCKER_HOME=$DOCKER_HOME \
            -e SSH_PORT=$SSH_PORT \
            -v /etc/passwd:/etc/passwd:ro \
            -v /etc/group:/etc/group:ro \
            -v /etc/localtime:/etc/localtime:ro \
            --gpus all \
            --ipc host \
            --security-opt seccomp=unconfined \
            --shm-size=4G \
            --net host \
            --restart always \
            --name ${CUDA_DEV} \
            --volume `pwd`:/cuda \
            $IMG \
            /bin/bash

  docker exec $CUDA_DEV bash -c 'mkdir -p $DOCKER_HOME \
    && touch $DOCKER_HOME/.profile \
    && chown -R $DOCKER_USER_ID:$DOCKER_GRP_ID $DOCKER_HOME'
  docker exec --user $(id -u):$(id -g) $CUDA_DEV bash -c 'if [ ! -e $DOCKER_HOME/bin/blade ];
    then /cuda/third_party/blade/install; \
    fi'
  docker cp ${DOCKER_HOME}/.ssh/authorized_keys ${CUDA_DEV}:/root/.ssh/authorized_keys
  docker exec $CUDA_DEV bash -c 'sed -i "s/#Port 22/Port ${SSH_PORT}/" /etc/ssh/sshd_config \
    && sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/" /etc/ssh/sshd_config \
    && sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config \
    && chmod 600 /root/.ssh/authorized_keys \
    && chown root:root /root/.ssh/authorized_keys \
    && service ssh start'

  if [ $? -ne 0 ];then
    error "Failed to start docker container \"${CUDA_DEV}\" based on image: $IMG"
    exit 1
  fi

  ok "Finished setting up docker environment. Now you can enter with: bash docker_run.sh\n"
  ok "Enjoy!\n"
}

main "$@"

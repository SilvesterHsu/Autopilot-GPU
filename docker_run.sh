#!/bin/bash
set -e

# PROJECT_PATH=$(cd "$(dirname "$0")";pwd)
PROJECT_PATH=$(pwd)
PROJECT_NAME="${PROJECT_PATH##*/}"
PROJECT_DEV="develop_${PROJECT_NAME}_${USER}"

if [ "$USER" != "root" ];then
  docker exec $PROJECT_DEV bash -c "echo '$USER ALL=NOPASSWD: ALL' >> /etc/sudoers"
fi

docker exec -it  $PROJECT_DEV /bin/bash -c "source /root/.profile && cd /workspace && /bin/zsh"

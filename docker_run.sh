#!/bin/bash
set -e

CUDA_DEV="develop_cuda_${USER}"

if [ "$USER" != "root" ];then
  docker exec $CUDA_DEV bash -c "echo '$USER ALL=NOPASSWD: ALL' >> /etc/sudoers"
fi

docker exec -it  $CUDA_DEV /bin/bash -c "source /root/.profile && cd /root && /bin/zsh"

#!/bin/bash

set -eu

export DOCKER_CLI_EXPERIMENTAL=enabled


# QEMU version variables
QEMU_EXE=qemu-arm-static
QEMU_VERSION=v4.2.0-6

# download qemu
curl -L https://github.com/multiarch/qemu-user-static/releases/download/${QEMU_VERSION}/${QEMU_EXE}.tar.gz | tar zxvf - -C .

# https://stackoverflow.com/questions/37935415/bash-regex-string-variable-match

# download estep/manifest-tool
curl -L https://github.com/estesp/manifest-tool/releases/download/v1.0.0/manifest-tool-linux-amd64 -o manifest-tool && \
chmod 744 manifest-tool && \
ls -l

# Register qemu-*-static for all supported processors except the 
# current one, but also remove all registered binfmt_misc before

docker run --rm --privileged multiarch/qemu-user-static:register --reset --credential yes

docker version

docker pull --platform linux/arm/v6 alpine:latest

docker pull --platform linux/arm/v7 alpine:latest

docker buildx create --name armos --platform linux/arm/v6,linux/arm/v7,linux/amd64

docker buildx use armos

docker buildx inspect --bootstrap

docker buildx ls

echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

docker run --rm --privileged multiarch/qemu-user-static:register --reset --credential yes

# [ $$(which qemu-aarch64-static) ] || echo "please install qemu-user-static"

docker buildx build --push --progress plain --platform linux/arm/v6,linux/arm/v7,linux/amd64 -t manios/nagios-src-builder:bob-pasxa  . 

docker logout

# freeswitch 1.6 for Kubernetes w/ manifests

[![Build Status](https://travis-ci.org/sip-li/docker-freeswitch.svg?branch=master)](https://travis-ci.org/sip-li/docker-freeswitch) [![Docker Pulls](https://img.shields.io/docker/pulls/callforamerica/freeswitch.svg)](https://store.docker.com/community/images/callforamerica/freeswitch)

## Maintainer

Joe Black <joeblack949@gmail.com>

## Description

Minimal image with <features>.  This image uses a custom version of Debian Linux (Jessie) that I designed weighing in at ~22MB compressed.

## Build Environment

Build environment variables are often used in the build script to bump version numbers and set other options during the docker build phase.  Their values can be overridden using a build argument of the same name.

* `ERLANG_VERSION`
* `FREESWITCH_VERSION`

The following variables are standard in most of our dockerfiles to reduce duplication and make scripts reusable among different projects:

* `APP`: freeswitch
* `USER`: freeswitch
* `HOME` /opt/freeswitch


## Run Environment

Run environment variables are used in the entrypoint script to render configuration templates, perform flow control, etc.  These values can be overridden when inheriting from the base dockerfile, specified during `docker run`, or in kubernetes manifests in the `env` array.

[todo]


## Usage

### Under docker (manual-build)

If building and running locally, feel free to use the convenience targets in the included `Makefile`.

* `make build`: rebuilds the docker image.
* `make launch`: launch for testing.
* `make logs`: tail the logs of the container.
* `make shell`: exec's into the docker container interactively with tty and bash shell.
* `make test`: test's the launched container.
* *and many others...*


### Under docker (pre-built)

All of our docker-* repos in github have CI pipelines that push to docker cloud/hub.  

This image is available at:
* [https://store.docker.com/community/images/callforamerica/freeswitch](https://store.docker.com/community/images/callforamerica/freeswitch)
*  [https://hub.docker.com/r/callforamerica/freeswitch](https://hub.docker.com/r/callforamerica/freeswitch).

and through docker itself: `docker pull callforamerica/freeswitch`

To run:

```bash
docker run -d \
    --name freeswitch \
    -h freeswitch.local \
    -p "11000:10000" \
    -p "11000:10000/udp" \
    -p "16384-16484:16384-16484/udp" \
    -p "8021:8021" \
    -p "8031:8031" \
    --cap-add IPC_LOCK \
    --cap-add SYS_NICE \
    --cap-add SYS_RESOURCE \
    --cap-add NET_ADMIN \
    --cap-add NET_RAW \
    --cap-add NET_BROADCAST \
    callforamerica/freeswitch
```

**NOTE:** Please reference the Run Environment section for the list of available environment variables.


### Under Kubernetes

Edit the manifests under `kubernetes/` to reflect your specific environment and configuration.

Create a secret for the erlang cookie:
```bash
kubectl create secret generic erlang-cookie --from-literal=erlang.cookie=$(LC_ALL=C tr -cd '[:alnum:]' < /dev/urandom | head -c 64)
```

Create a secret for the freeswitch credentials:
```bash
kubectl create secret generic freeswitch-creds --from-literal=freeswitch.event-socket.password=$(sed $(perl -e "print int rand(99999)")"q;d" /usr/share/dict/words)
```

Deploy freeswitch:
```bash
kubectl create -f kubernetes
```


## Issues

**ref:**  [https://github.com/sip-li/docker-freeswitch/issues](https://github.com/sip-li/docker-freeswitch/issues)

SHELL = /bin/zsh
SHELLFLAGS = -c

NAME := $(shell basename $(PWD) | cut -d'-' -f2)
BRANCH ?= $(shell basename $(shell git status | head -1 | rev | cut -d" " -f1 | rev))
ifeq ($(BRANCH),master)
	TAG := latest
else
	TAG := $(BRANCH)
endif
DOCKER_USER ?= callforamerica
DOCKER_IMAGE := $(DOCKER_USER)/$(NAME):$(TAG)

BUILD_TOKEN = f7cb35b0-df97-4b72-8cfc-24503f01776e

CSHELL = bash -l
# VOLUME_ARGS = --tmpfs /volumes/ram:size=512M
ENV_ARGS = --env-file default.env
PORT_ARGS = -p "11000:10000" -p "11000:10000/udp" -p "16384-16484:16384-16484/udp" -p "8021:8021" -p "8031:8031"
CAP_ARGS = --cap-add IPC_LOCK --cap-add SYS_NICE --cap-add SYS_RESOURCE --cap-add NET_ADMIN --cap-add NET_RAW --cap-add NET_BROADCAST
NETWORK_ARGS = --network local

-include ../Makefile.inc

.PHONY: all build rebuild tag info test create-network run launch shell
.PHONY: launch-as-dep rmf-as-dep logs start kill stop rm rmi rmf hub-login
.PHONY: hub-push hub-build kube-local kube-local-rm kube-deploy kube-rm

build:
	@docker build -t $(DOCKER_IMAGE) --force-rm .
	@-test $(LOCAL) && $(MAKE) dclean

rebuild:
	@docker build -t $(DOCKER_IMAGE) --force-rm --no-cache .
	@-test $(LOCAL) && $(MAKE) dclean

tag:
	@test $(ALT_TAG) && \
		docker tag $(DOCKER_IMAGE) $(DOCKER_USER)/$(NAME):$(ALT_TAG)

info:
	@echo "NAME: 		$(NAME)"
	@echo "BRANCH: 	$(BRANCH)"
	@echo "TAG: 		$(TAG)"
	@echo "DOCKER_USER: 	$(DOCKER_USER)"
	@echo "DOCKER_IMAGE: 	$(DOCKER_IMAGE)"

test:
	@tests/run

create-network:
	@-docker network create local

run:
	@docker run -it --rm --name $(NAME) $(ENV_ARGS) $(NETWORK_ARGS) \
		$(DOCKER_IMAGE) $(CSHELL)

launch:
	@docker run -d --name $(NAME) -h $(NAME).local \
		$(ENV_ARGS) $(VOLUME_ARGS) $(PORT_ARGS) $(CAP_ARGS) $(NETWORK_ARGS) \
		$(DOCKER_IMAGE)

shell:
	@docker exec -ti $(NAME) $(CSHELL)

launch-as-dep:
	@$(MAKE) launch

rmf-as-dep:
	@$(MAKE) rmf

logs:
	@docker logs -f $(NAME)

start:
	@docker start $(NAME)

kill:
	@-docker kill $(NAME)

stop:
	@-docker stop $(NAME)

rm:
	@-docker rm $(NAME)

rmi:
	@-docker rmi $(DOCKER_IMAGE)

rmf:
	@-docker rm --force $(NAME)

hub-login:
	@docker login -u $(DOCKER_USER) -p $(DOCKER_PASS)

hub-push:
	@docker push $(DOCKER_USER)/$(NAME)

hub-build:
	@curl -s -X POST -H "Content-Type: application/json" \
		--data '{"docker_tag": "$(TAG)"}' \
		https://registry.hub.docker.com/u/$(DOCKER_USER)/$(NAME)/trigger/$(BUILD_TOKEN)/

kube-local:
	@kubectl apply -f tests/manifests/local.yaml

kube-local-rm:
	@kubectl delete -f tests/manifests/local.yaml

kube-deploy:
	@kubectl apply -f kubernetes

kube-rm:
	@kubectl delete -f kubernetes

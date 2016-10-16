NS = vp
NAME = freeswitch
APP_VERSION = 1.6
IMAGE_VERSION = 2.0
VERSION = $(APP_VERSION)-$(IMAGE_VERSION)
LOCAL_TAG = $(NS)/$(NAME):$(VERSION)

REGISTRY = callforamerica
ORG = vp
REMOTE_TAG = $(REGISTRY)/$(NAME):$(VERSION)

GITHUB_REPO = docker-freeswitch
DOCKER_REPO = freeswitch
BUILD_BRANCH = master

VOLUME_ARGS = --tmpfs /volumes/ram:size=512M
ENV_ARGS = --env-file default.env
PORT_ARGS = -p "11000:10000" -p "11000:10000/udp" -p "16384-16484:16384-16484/udp" -p "8021:8021" -p "8031:8031"
CAP_ARGS = --cap-add sys_nice
SHELL = bash -l

-include ../Makefile.inc

.PHONY: all build test release shell run start stop rm rmi default

all: build

checkout:
	@git checkout $(BUILD_BRANCH)

build:
	@docker build -t $(LOCAL_TAG) --force-rm .
	@$(MAKE) tag
	@$(MAKE) dclean

tag:
	@docker tag $(LOCAL_TAG) $(REMOTE_TAG)

rebuild:
	@docker build -t $(LOCAL_TAG) --force-rm --no-cache .
	@$(MAKE) tag
	@$(MAKE) dclean

test:
	@rspec ./tests/*.rb

commit:
	@git add -A .
	@git commit

push:
	@git push origin master

shell:
	@docker exec -ti $(NAME) $(SHELL)

run:
	@docker run -it --rm --name $(NAME) $(LOCAL_TAG) $(SHELL)

launch:
	@docker run -d --name $(NAME) -h $(NAME).local $(ENV_ARGS) $(VOLUME_ARGS) $(PORT_ARGS) $(CAP_ARGS) $(LOCAL_TAG)

launch-fast:
	@docker run -d --name $(NAME) -h $(NAME).local $(ENV_ARGS) $(VOLUME_ARGS) $(PORT_ARGS) $(CAP_ARGS) $(LOCAL_TAG)

launch-net:
	@docker run -d --name $(NAME) -h $(NAME).local $(ENV_ARGS) $(VOLUME_ARGS) $(PORT_ARGS) $(CAP_ARGS) --network=local --net-alias $(NAME).local $(LOCAL_TAG)

reloadxml:
	@docker exec $(NAME) fs_cli -x 'reloadxml'

http-clear-cache:
	@docker exec $(NAME) fs_cli -x 'http_clear_cache' 

erlang-status:
	@docker exec $(NAME) fs_cli -x 'erlang status'

sofia-status:
	@docker exec $(NAME) fs_cli -x 'sofia status'

launch-as-dep:
	@$(MAKE) launch-net

create-network:
	@docker network create -d bridge local

proxies-up:
	@cd ../docker-aptcacher-ng && make remote-persist
	#@cd ../docker-squid && make remote-persist

logs:
	@docker logs $(NAME)

logsf:
	@docker logs -f $(NAME)

start:
	@docker start $(NAME)

kill:
	@docker kill $(NAME)

stop:
	@docker stop $(NAME)

rm:
	@docker rm $(NAME)

rmf:
	@docker rm -f $(NAME)
	
rmi:
	@docker rmi $(LOCAL_TAG)
	@docker rmi $(REMOTE_TAG)

# dclean:
# 	@-docker ps -aq | gxargs -I{} docker rm {} 2> /dev/null || true
# 	@-docker images -f dangling=true -q | xargs docker rmi
# 	@-docker volume ls -f dangling=true -q | xargs docker volume rm

kube-deploy:
	@kubectl create -f kubernetes/$(NAME)-deployment.yaml --record

kube-deploy-daemonset:
	@kubectl create -f kubernetes/$(NAME)-daemonset.yaml

kube-edit-daemonset:
	@kubectl edit daemonset/$(NAME)

kube-delete-daemonset:
	@kubectl delete daemonset/$(NAME)

kube-deploy-service:
	@kubectl create -f kubernetes/$(NAME)-service.yaml

kube-delete-service:
	@kubectl delete svc $(NAME)

kube-replace-service:
	@kubectl replace -f kubernetes/$(NAME)-service.yaml

kube-logsf:
	@kubectl logs -f $(shell kubectl get po | grep $(NAME) | cut -d' ' -f1)

kube-logsft:
	@kubectl logs -f --tail=25 $(shell kubectl get po | grep $(NAME) | cut -d' ' -f1)

kube-shell:
	@kubectl exec -ti $(shell kubectl get po | grep $(NAME) | cut -d' ' -f1) -- bash

kube-erlang-status:
	@kubectl exec $(shell kubectl get po | grep $(NAME) | cut -d' ' -f1) -- fs_cli -x 'erlang status'

kube-sofia-status:
	@kubectl exec $(shell kubectl get po | grep $(NAME) | cut -d' ' -f1) -- fs_cli -x 'sofia status'

kube-reloadxml:
	@kubectl exec $(shell kubectl get po | grep $(NAME| cut -d' ' -f1) -- fs_cli -x 'reloadxml'

kube-http-clear-cache:
	@kubectl exec $(shell kubectl get po | grep $(NAME| cut -d' ' -f1) -- fs_cli -x 'http_clear_cache' 

default: build
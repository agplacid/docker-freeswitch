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
	@docker exec -ti $(NAME) /bin/bash

run:
	@docker run -it --rm --name $(NAME) --entrypoint bash $(LOCAL_TAG)

launch:
	@docker run -d --name $(NAME) --tmpfs /usr/share/freeswitch/http_cache:size=512M --tmpfs /var/lib/freeswitch:size=512M --cap-add sys_nice --privileged $(LOCAL_TAG)

launch-fast:
	@docker run -d --name $(NAME) -e "FREESWITCH_SKIP_SOUNDS=true" --tmpfs /usr/share/freeswitch/http_cache:size=512M --tmpfs /var/lib/freeswitch:size=512M --cap-add sys_nice --privileged $(LOCAL_TAG)

launch-net:
	@docker run -d --name $(NAME) -h freeswitch.local -e "FREESWITCH_SKIP_SOUNDS=true" -e "FREESWITCH_DISABLE_NAT_DETECTION=false" -e "FREESWITCH_RTP_START_PORT=16384" -e "FREESWITCH_RTP_END_PORT=16484" -p "11000:10000" -p "11000:10000/udp" -p "16384-16484:16384-16484/udp" --tmpfs /usr/share/freeswitch/http_cache:size=512M --tmpfs /usr/share/freeswitch/http_cache:size=512M --cap-add sys_nice --privileged --network=local --net-alias freeswitch.local $(LOCAL_TAG)

create-network:
	@docker network create -d bridge local

proxies-up:
	@cd ../docker-aptcacher-ng && make remote-persist
	@cd ../docker-squid && make remote-persist

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

dclean:
	@-docker ps -aq | gxargs -I{} docker rm {} 2> /dev/null || true
	@-docker images -f dangling=true -q | xargs docker rmi
	@-docker volume ls -f dangling=true -q | xargs docker volume rm

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

freeswitch-erlang-status:
	@kubectl exec $(shell kubectl get po | grep $(NAME) | cut -d' ' -f1) -- fs_cli -x 'erlang status'

freeswitch-sofia-status:
	@kubectl exec $(shell kubectl get po | grep $(NAME) | cut -d' ' -f1) -- fs_cli -x 'sofia status'

freeswitch-reload:
	@kubectl exec $(shell kubectl get po | grep $(NAME| cut -d' ' -f1) -- fs_cli -x 'reloadxml'

freeswitch-http-clear-cache:
	@kubectl exec $(shell kubectl get po | grep $(NAME| cut -d' ' -f1) -- fs_cli -x 'http_clear_cache' 

default: build
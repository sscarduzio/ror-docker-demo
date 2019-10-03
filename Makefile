.DEFAULT_GOAL := help
SHELL         := /bin/bash
PROJECT_NAME  := Elasticstack
BRANCH        := $(shell git rev-parse --abbrev-ref HEAD)
TAG           := $(shell git describe --tags --abbrev=0)
DOCKER_LABEL  := beshultd/ror_enterprise
DOCKER_TAG    := $(shell curl -s "https://raw.githubusercontent.com/sscarduzio/elasticsearch-readonlyrest-plugin/master/gradle.properties" | grep publi| cut -c24-99)

# colours
ccblack=$(shell echo -e "\033[0;30m")
ccred=$(shell echo -e "\033[0;31m")
ccgreen=$(shell echo -e "\033[0;32m")
ccyellow=$(shell echo -e "\033[0;33m")
ccblue=$(shell echo -e "\033[0;34m")
ccmagenta=$(shell echo -e "\033[0;35m")
cccyan=$(shell echo -e "\033[0;36m")
ccwhite=$(shell echo -e "\033[0;37m")
ccend=$(shell echo -e "\033[0m")

##@ Docker
build:	## build the container
	@docker build --rm --tag $(DOCKER_LABEL) $(CURDIR)

shell: build	## get a shell in the container
	@docker run --rm -ti -v $(CURDIR):/code -p 9200:9200 -p 5601:5601 $(DOCKER_LABEL) bash

run: build	## run the container
	@sysctl -w vm.max_map_count=300000 || echo  "$(ccmagenta)>>>IMPORTANT<<<< ------ When  in Linux, don't forget to run sysctl -w vm.max_map_count=300000 as root! --------$(ccend)" 
	@docker run --ulimit nofile=300000:300000 --rm --init --name $(PROJECT_NAME) -ti -p 9200:9200 -p 5601:5601 $(DOCKER_LABEL)

push: build	##  tag and push
	@docker push  $(DOCKER_LABEL)

attach: ## Attach to container shell
	@docker exec -ti ${PROJECT_NAME} bash

stop: ## get a shell in the container
	@docker stop $(PROJECT_NAME)

clean:	## Clean docker container and image
	@-docker rm -f $(PROJECT_NAME)
	@-docker rmi $(DOCKER_LABEL)

##@ Helpers
.PHONY: cloc help
cloc:	## Show Lines of Code analysis
	@cloc --vcs git --quiet

help:	## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "$(ccmagenta)$(PROJECT_NAME)$(ccend): $(ccred)$(TAG)$(ccend)\n\nUsage:\n  make $(cccyan)<target>$(ccend)\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(cccyan)%-15s$(ccend) %s\n", $$1, $$2 } /^##@/ { printf "\n$(cccyan)%s$(ccend)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

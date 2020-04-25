.PHONY: deps build start stop

SHELL := $(shell which bash)
DOCKER := $(shell command -v docker)
COMPOSE := $(shell command -v docker-compose)

include .env
export $(shell sed 's/=.*//' .env)

export NX_USER := $(shell echo $${USER})
export NX_UID := $(shell id -u)
export NX_GID := $(shell id -g)

deps:
ifndef DOCKER
	@echo "docker is not available."
	@exit 127
endif
ifndef COMPOSE
	@echo "docker-compose is not available."
	@exit 127
endif
	@echo "All done."

build: deps
	$(COMPOSE) build --build-arg NX_USER=$${NX_USER} --build-arg NX_UID=$${NX_UID} --build-arg NX_GID=$${NX_GID}

start:
	@mkdir nexus_data
	$(COMPOSE) up -d

stop: deps
	$(COMPOSE) down

# Local development. `make help` lists the targets.

NAMESPACE  ?= duly
COMPOSE    := docker compose -f dev/docker-compose.dev.yml

.DEFAULT_GOAL := help
.PHONY: help up down reset status logs restart compose-up compose-down

help:
	@grep -hE '^[a-z-]+:.*##' $(MAKEFILE_LIST) \
		| sed -e 's/:.*##/\t/' -e 's/^/  make /' \
		| expand -t 24

## --- Kubernetes (minikube) ---

up: ## Apply every manifest under k8s/
	kubectl apply -k k8s/

down: ## Delete the namespace, taking Secrets and PVCs with it
	kubectl delete namespace $(NAMESPACE) --ignore-not-found --wait

reset: down up ## Tear down and bring back up

status: ## What is running, and the most recent events
	kubectl get all -n $(NAMESPACE)
	@echo
	kubectl get events -n $(NAMESPACE) --sort-by=.lastTimestamp | tail -15

logs: ## Follow one workload: make logs svc=duly-backend
	kubectl logs -n $(NAMESPACE) -f deploy/$(svc)

restart: ## Pick up a reloaded image: make restart svc=duly-backend
	kubectl rollout restart -n $(NAMESPACE) deploy/$(svc)
	kubectl rollout status -n $(NAMESPACE) deploy/$(svc)

## --- Docker Compose (the dev stack) ---

compose-up: ## Start the dev stack and wait for it to be healthy
	$(COMPOSE) up -d --wait

compose-down: ## Stop the dev stack, keeping the database
	$(COMPOSE) down

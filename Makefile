# Local development. `make help` lists the targets.

NAMESPACE   ?= duly
COMPOSE     := docker compose -f dev/docker-compose.dev.yml
SECRETS_ENV := k8s/chatbot/anthropic.env

.DEFAULT_GOAL := help
.PHONY: help up down reset nuke secrets status logs restart compose-up compose-down

help:
	@grep -hE '^[a-z-]+:.*##' $(MAKEFILE_LIST) \
		| sed -e 's/:.*##/\t/' -e 's/^/  make /' \
		| expand -t 24

## --- Kubernetes (minikube) ---

up: secrets ## Apply every manifest under k8s/
	kubectl apply -k k8s/

secrets: ## Recreate the Anthropic secret from k8s/chatbot/anthropic.env
	@if [ -f $(SECRETS_ENV) ]; then \
		kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f - >/dev/null; \
		kubectl create secret generic duly-chatbot-anthropic -n $(NAMESPACE) \
			--from-env-file=$(SECRETS_ENV) --dry-run=client -o yaml | kubectl apply -f -; \
	else \
		echo "!! $(SECRETS_ENV) is missing, so the chatbot will sit in"; \
		echo "!! CreateContainerConfigError. Create it with one line:"; \
		echo "!!   ANTHROPIC_API_KEY=sk-ant-..."; \
	fi

down: ## Remove the workloads, keeping the database and secrets
	kubectl delete deploy,statefulset,job,service,ingress \
		-n $(NAMESPACE) --all --ignore-not-found --wait

reset: down up ## Recycle the workloads, keeping data

nuke: ## Delete the namespace, DESTROYING the database and secrets
	@printf 'This deletes the %s namespace, its PVC and its data. Type yes: ' $(NAMESPACE)
	@read ok && [ "$$ok" = yes ] || { echo "aborted"; exit 1; }
	kubectl delete namespace $(NAMESPACE) --ignore-not-found --wait

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

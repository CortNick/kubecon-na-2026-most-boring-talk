# Workshop shortcuts. Run `make help` to list them.

# Delay 'make db-slow' adds to every database reply, in milliseconds: make db-slow LATENCY=3000
LATENCY ?= 1000

.PHONY: help setup ui k8s backup kill-backstage db-slow db-unreachable db-heal disaster restart-backend catalog-source restore status register seed reset teardown

help: ## List targets
	@grep -E '^[a-z0-9-]+:.*##' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

setup: ## Create the cluster and start Backstage (runs automatically in Codespaces)
	@scripts/setup.sh

ui: ## Show the portal address and wait until it is ready
	@scripts/ui.sh

k8s: ## Show the Backstage, Postgres and db-proxy pods in Kubernetes
	@scripts/k8s.sh

backup: ## Dump the whole Postgres into backups/
	@scripts/backup.sh

kill-backstage: ## Kill the Backstage pod and watch Kubernetes replace it
	@scripts/kill-backstage.sh

db-slow: ## Make the database slow (+LATENCY ms on every reply)
	@LATENCY=$(LATENCY) scripts/db-slow.sh

db-unreachable: ## Cut the network between Backstage and the database
	@scripts/db-unreachable.sh

db-heal: ## Fix the network between Backstage and the database
	@scripts/db-heal.sh

disaster: ## Lose the Postgres disk: delete its volume and pod
	@scripts/disaster.sh

restart-backend: ## Restart Backstage so it starts over on the empty database
	@scripts/restart-backend.sh

catalog-source: ## Show where the seed catalog comes from (and why it survives)
	@scripts/catalog-source.sh

restore: ## Restore the newest backup into a fresh Postgres
	@scripts/restore.sh

status: ## Show what Kubernetes and the Backstage API see, one command at a time
	@scripts/status.sh

register: ## Register legacy-billing through the API instead of the portal
	@scripts/register.sh

seed: ## Facilitator shortcut: run the template twice and register legacy-billing
	@scripts/seed.sh

reset: ## Back to the post-setup state, keeping the cluster (between runs)
	@scripts/reset.sh

teardown: ## Delete the workshop cluster completely
	@scripts/teardown.sh

SERVICE ?= svn

.DEFAULT_GOAL := help
.PHONY: help up down build rebuild sync refresh fresh start shell logs clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

up: ## Build if needed and start the SVN container
	docker compose up -d --build

down: ## Stop and remove the container (repo data persists in the volume)
	docker compose down

build: ## Build the image
	docker compose build

rebuild: ## Rebuild the image from scratch and restart
	docker compose build --no-cache
	docker compose up -d

sync: ## svnsync the mirror repo with develop.svn.wordpress.org (resumable)
	./mirror-wp-develop.sh

refresh: ## Wipe the working repo and replace it with a clean copy of the mirror
	docker compose exec -T $(SERVICE) /usr/local/bin/refresh-working-repo.sh

fresh: sync refresh ## Sync the mirror from upstream, then refresh the working repo

start: up sync refresh ## start the container, sync the mirror and refresh the working repo

shell: ## Open a shell in the container
	docker compose exec $(SERVICE) sh

logs: ## Follow container logs
	docker compose logs -f $(SERVICE)

clean: ## Stop the container and delete all repo data (mirror + working)
	docker compose down -v

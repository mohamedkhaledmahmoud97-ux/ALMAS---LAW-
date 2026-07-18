.PHONY: help up down restart logs status clean backup restore shell-postgres shell-redis db-init

# ALMAS LAW Docker Compose - Makefile
# Provides convenient commands for managing the development environment

# Docker Compose files
COMPOSE_FILE := docker-compose.yml
COMPOSE_PROD_FILE := docker-compose.prod.yml
ENV_FILE := .env

# Color output
BLUE := \033[0;34m
GREEN := \033[0;32m
RED := \033[0;31m
YELLOW := \033[0;33m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)ALMAS LAW Docker Compose Management$(NC)"
	@echo ""
	@echo "$(GREEN)Common Commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BLUE)%-15s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Usage:$(NC)"
	@echo "  make up              # Start all services"
	@echo "  make down            # Stop all services"
	@echo "  make logs            # Show all service logs"
	@echo "  make logs-postgres   # Show PostgreSQL logs only"
	@echo "  make status          # Show service status"

up: check-env ## Start all Docker services
	@echo "$(GREEN)Starting ALMAS LAW services...$(NC)"
	docker-compose -f $(COMPOSE_FILE) up -d
	@echo "$(GREEN)Services started. Waiting for health checks...$(NC)"
	@sleep 10
	@make status

down: ## Stop all Docker services
	@echo "$(YELLOW)Stopping ALMAS LAW services...$(NC)"
	docker-compose -f $(COMPOSE_FILE) stop
	@echo "$(GREEN)Services stopped$(NC)"

restart: ## Restart all Docker services
	@echo "$(YELLOW)Restarting ALMAS LAW services...$(NC)"
	docker-compose -f $(COMPOSE_FILE) restart
	@echo "$(GREEN)Services restarted$(NC)"

up-prod: check-env ## Start services with production configuration
	@echo "$(GREEN)Starting ALMAS LAW services (Production)...$(NC)"
	docker-compose -f $(COMPOSE_PROD_FILE) up -d
	@echo "$(GREEN)Production services started$(NC)"

down-prod: ## Stop production services
	@echo "$(YELLOW)Stopping ALMAS LAW production services...$(NC)"
	docker-compose -f $(COMPOSE_PROD_FILE) stop
	@echo "$(GREEN)Production services stopped$(NC)"

logs: ## Show logs from all services
	docker-compose -f $(COMPOSE_FILE) logs -f

logs-postgres: ## Show PostgreSQL logs
	docker-compose -f $(COMPOSE_FILE) logs -f postgres

logs-keycloak: ## Show Keycloak logs
	docker-compose -f $(COMPOSE_FILE) logs -f keycloak

logs-neo4j: ## Show Neo4j logs
	docker-compose -f $(COMPOSE_FILE) logs -f neo4j

logs-qdrant: ## Show Qdrant logs
	docker-compose -f $(COMPOSE_FILE) logs -f qdrant

logs-redis: ## Show Redis logs
	docker-compose -f $(COMPOSE_FILE) logs -f redis

logs-minio: ## Show MinIO logs
	docker-compose -f $(COMPOSE_FILE) logs -f minio

status: ## Show status of all services
	@echo "$(BLUE)Service Status:$(NC)"
	@docker-compose -f $(COMPOSE_FILE) ps
	@echo ""
	@echo "$(BLUE)Service URLs:$(NC)"
	@echo "  PostgreSQL         : localhost:5432"
	@echo "  Qdrant REST        : http://localhost:6333"
	@echo "  Qdrant gRPC        : localhost:6334"
	@echo "  Neo4j Browser      : http://localhost:7474"
	@echo "  Neo4j Bolt         : bolt://localhost:7687"
	@echo "  Redis              : localhost:6379"
	@echo "  MinIO API          : http://localhost:9000"
	@echo "  MinIO Console      : http://localhost:9001"
	@echo "  Keycloak           : http://localhost:8080"

clean: ## Remove all containers and volumes (WARNING: data loss!)
	@echo "$(RED)WARNING: This will remove all containers and volumes!$(NC)"
	@read -p "Are you sure? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		echo "$(YELLOW)Removing containers and volumes...$(NC)"; \
		docker-compose -f $(COMPOSE_FILE) down -v; \
		echo "$(GREEN)Cleanup complete$(NC)"; \
	else \
		echo "$(GREEN)Cleanup cancelled$(NC)"; \
	fi

backup-postgres: ## Backup PostgreSQL database
	@echo "$(BLUE)Backing up PostgreSQL database...$(NC)"
	@mkdir -p ./backups
	@docker-compose -f $(COMPOSE_FILE) exec -T postgres pg_dump -U postgres almas_db > ./backups/postgres_backup_$$(date +%Y%m%d_%H%M%S).sql
	@echo "$(GREEN)PostgreSQL backup complete$(NC)"

restore-postgres: ## Restore PostgreSQL database (INTERACTIVE)
	@echo "$(BLUE)PostgreSQL Restore$(NC)"
	@ls -lh ./backups/postgres_backup_*.sql 2>/dev/null || { echo "$(RED)No backups found in ./backups/$(NC)"; exit 1; }
	@read -p "Enter backup file name: " backup_file; \
	if [ -f "./backups/$$backup_file" ]; then \
		echo "$(YELLOW)Restoring from $$backup_file...$(NC)"; \
		docker-compose -f $(COMPOSE_FILE) exec -T postgres psql -U postgres almas_db < ./backups/$$backup_file; \
		echo "$(GREEN)Restore complete$(NC)"; \
	else \
		echo "$(RED)File not found: ./backups/$$backup_file$(NC)"; \
	fi

shell-postgres: ## Open PostgreSQL CLI
	docker-compose -f $(COMPOSE_FILE) exec postgres psql -U postgres -d almas_db

shell-redis: ## Open Redis CLI
	docker-compose -f $(COMPOSE_FILE) exec redis redis-cli -a $$(grep REDIS_PASSWORD $(ENV_FILE) | cut -d '=' -f2)

shell-neo4j: ## Open Neo4j Cypher shell
	docker-compose -f $(COMPOSE_FILE) exec neo4j cypher-shell -u neo4j -p $$(grep NEO4J_PASSWORD $(ENV_FILE) | cut -d '=' -f2)

shell-minio: ## Access MinIO container
	docker-compose -f $(COMPOSE_FILE) exec minio sh

db-init: ## Run database initialization scripts
	@echo "$(BLUE)Running database initialization...$(NC)"
	docker-compose -f $(COMPOSE_FILE) exec -T postgres psql -U postgres almas_db < ./init-scripts/postgres/01-init.sql
	@echo "$(GREEN)Database initialization complete$(NC)"

prune: ## Remove unused Docker resources
	@echo "$(YELLOW)Pruning Docker resources...$(NC)"
	docker system prune -f
	@echo "$(GREEN)Prune complete$(NC)"

check-env: ## Check if .env file exists
	@if [ ! -f "$(ENV_FILE)" ]; then \
		echo "$(YELLOW)Warning: $(ENV_FILE) not found. Creating from $(ENV_FILE).example...$(NC)"; \
		if [ -f "$(ENV_FILE).example" ]; then \
			cp $(ENV_FILE).example $(ENV_FILE); \
			echo "$(YELLOW)Please update $(ENV_FILE) with your configuration$(NC)"; \
		else \
			echo "$(RED)Error: $(ENV_FILE).example not found$(NC)"; \
			exit 1; \
		fi \
	fi

ps: status ## Alias for status

pull: ## Pull latest images
	@echo "$(BLUE)Pulling latest images...$(NC)"
	docker-compose -f $(COMPOSE_FILE) pull
	@echo "$(GREEN)Images updated$(NC)"

build: ## Build custom images (if needed)
	docker-compose -f $(COMPOSE_FILE) build

version: ## Show Docker and Docker Compose versions
	@echo "$(BLUE)Docker Version:$(NC)"
	@docker --version
	@echo "$(BLUE)Docker Compose Version:$(NC)"
	@docker-compose --version

health-check: ## Verify all services are healthy
	@echo "$(BLUE)Performing health checks...$(NC)"
	@echo "PostgreSQL: " && docker-compose -f $(COMPOSE_FILE) exec -T postgres pg_isready -U postgres && echo "✓" || echo "✗"
	@echo "Qdrant: " && docker-compose -f $(COMPOSE_FILE) exec -T qdrant curl -s http://localhost:6333/health > /dev/null && echo "✓" || echo "✗"
	@echo "Neo4j: " && docker-compose -f $(COMPOSE_FILE) exec -T neo4j curl -s http://localhost:7474 > /dev/null && echo "✓" || echo "✗"
	@echo "Redis: " && docker-compose -f $(COMPOSE_FILE) exec -T redis redis-cli -a $$(grep REDIS_PASSWORD $(ENV_FILE) | cut -d '=' -f2) ping > /dev/null && echo "✓" || echo "✗"
	@echo "MinIO: " && docker-compose -f $(COMPOSE_FILE) exec -T minio curl -s http://localhost:9000/minio/health/live > /dev/null && echo "✓" || echo "✗"
	@echo "Keycloak: " && docker-compose -f $(COMPOSE_FILE) exec -T keycloak curl -s http://localhost:8080 > /dev/null && echo "✓" || echo "✗"

# Aliases
start: up
stop: down
start-prod: up-prod
stop-prod: down-prod
restart-prod: ## Restart production services
	@echo "$(YELLOW)Restarting ALMAS LAW production services...$(NC)"
	docker-compose -f $(COMPOSE_PROD_FILE) restart
	@echo "$(GREEN)Production services restarted$(NC)"

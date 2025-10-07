# Makefile for Okta MCP Server
# Simplifies common Docker commands

.PHONY: help build start stop restart logs clean shell status gemini

# Variables
DOCKER_IMAGE := okta-mcp-server
GATEWAY_IMAGE := okta-mcp-server-gateway
DOCKER_TAG := latest
COMPOSE_FILE := docker-compose.yml

# Colors for display
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Default target
.DEFAULT_GOAL := help

help: ## Display this help message
	@echo "$(GREEN)Okta MCP Server - Docker Management$(NC)"
	@echo ""
	@echo "$(BLUE)Quick Start:$(NC)"
	@echo "  1. $(YELLOW)make setup$(NC)      - Initial setup"
	@echo "  2. $(YELLOW)make build$(NC)      - Build images"
	@echo "  3. $(YELLOW)make start$(NC)      - Start services"
	@echo ""
	@echo "$(BLUE)Available Commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-18s$(NC) %s\n", $$1, $$2}'

# Setup and Build Commands
setup: ## Initial setup (directories, env template, source check)
	@echo "$(GREEN)Setting up environment...$(NC)"
	@chmod +x docker-utils.sh 2>/dev/null || true
#	@./docker-utils.sh setup
	@echo "$(GREEN)Setup complete! Configure .env if using docker compose$(NC)"

build: ## Build all Docker images
	@echo "$(GREEN)Building Docker images...$(NC)"
	@./docker-utils.sh build

build-main: ## Build only the main MCP server image
	@echo "$(GREEN)Building main image...$(NC)"
	@docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

build-gateway: ## Build only the gateway image
	@echo "$(GREEN)Building gateway image...$(NC)"
	@docker build -f Dockerfile-gateway -t $(GATEWAY_IMAGE):$(DOCKER_TAG) .

# Service Management Commands
start: ## Start services (requires .env)
	@echo "$(GREEN)Starting all services...$(NC)"
	@./docker-utils.sh start

start-gateway: ## Start only gateway service
	@echo "$(GREEN)Starting gateway service...$(NC)"
	@./docker-utils.sh start okta-mcp-server-gateway
	@echo "$(GREEN)Gateway available at http://localhost:8000$(NC)"

start-gemini: ## Start only gateway service
	@echo "$(GREEN)Starting gemini service...$(NC)"
	@./docker-utils.sh start gemini-cli

stop: ## Stop services
	@echo "$(YELLOW)Stopping services...$(NC)"
	@./docker-utils.sh stop

restart: ## Restart services
	@echo "$(YELLOW)Restarting services...$(NC)"
	@./docker-utils.sh restart

# Logging Commands
logs: ## Show logs for main service
	@docker compose logs -f okta-mcp-server-gateway

logs-gateway: ## Show logs for gateway service
	@docker compose logs -f okta-mcp-server-gateway

logs-mcp: ## Show logs for MCP server service
	@docker compose exec -it okta-mcp-server tail -f /var/log/okta-mcp/server.log

logs-all: ## Show logs for all services
	@docker compose logs -f

# Utility Commands
status: ## Display service status
	@echo "$(GREEN)Service Status:$(NC)"
	@docker compose ps

shell: ## Open shell in main container
	@./docker-utils.sh shell okta-mcp-server

shell-gateway: ## Open shell in gateway container
	@./docker-utils.sh shell okta-mcp-server-gateway

health: ## Check service health
	@./docker-utils.sh health

gateway-test: ## Test gateway HTTP endpoint
	@./docker-utils.sh test-gateway

# Maintenance Commands
clean: ## Clean Docker resources (containers, volumes)
	@echo "$(YELLOW)Cleaning Docker resources...$(NC)"
	@./docker-utils.sh clean

clean-all: ## Complete cleanup including images
	@echo "$(RED)Removing all resources including images...$(NC)"
	@docker compose down -v --rmi all --remove-orphans
	@docker system prune -af
	@echo "$(GREEN)Complete cleanup finished$(NC)"

update: ## Pull latest changes and rebuild
	@echo "$(GREEN)Updating project...$(NC)"
	@git pull
	@git submodule update --remote --merge
	@$(MAKE) build

# Configuration Commands
check: ## Verify environment and source
	@./docker-utils.sh check-env
	@./docker-utils.sh check-source

check-env: ## Verify .env configuration
	@./docker-utils.sh check-env

check-source: ## Verify okta-mcp-server source
	@./docker-utils.sh check-source

# Debug Commands
debug: ## Run services in debug mode
	@echo "$(GREEN)Starting in debug mode...$(NC)"
	@OKTA_LOG_LEVEL=DEBUG docker compose up

debug-gateway: ## Debug gateway service only
	@echo "$(GREEN)Starting gateway in debug mode...$(NC)"
	@OKTA_LOG_LEVEL=DEBUG docker compose up okta-mcp-server-gateway

# Docker Run Examples
run-example: ## Show example of standalone docker run
	@echo "$(BLUE)Example: Run MCP server without docker compose$(NC)"
	@echo ""
	@echo "$(YELLOW)docker run -i --rm \\$(NC)"
	@echo "  -e OKTA_ORG_URL=\"https://your-org.okta.com\" \\"
	@echo "  -e OKTA_CLIENT_ID=\"your_client_id\" \\"
	@echo "  -e OKTA_KEY_ID=\"your_key_id\" \\"
	@echo "  -e OKTA_PRIVATE_KEY=\"-----BEGIN PRIVATE KEY-----...\" \\"
	@echo "  -e OKTA_SCOPES=\"okta.users.read okta.groups.read\" \\"
	@echo "  okta-mcp-server"
	@echo ""
	@echo "$(GREEN)No .env file needed with this method!$(NC)"

gemini: ## Run Gemini tests inside container
	@echo "$(GREEN)Running Gemini-cli...$(NC)"
	@./docker-utils.sh gemini

# Aliases for convenience
up: start ## Alias for start
down: stop ## Alias for stop
ps: status ## Alias for status
sh: shell ## Alias for shell

# Combined operations
full-start: setup build start ## Complete setup, build, and start
quick-test: build-main run-example ## Build and show run example
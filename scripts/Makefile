# Okta MCP Server - Native Installation Makefile
# Author: Fabio Grasso
# License: Apache-2.0

# Variables
MCP_DIR := $(HOME)/okta-mcp-server
PYTHON := python3.13
UV := $(PYTHON) -m uv
SERVICE_NAME := okta-mcp
GATEWAY_SERVICE := okta-mcp-gateway
GATEWAY_PORT := 8000

# Colors for display
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
BLUE := \033[0;34m
NC := \033[0m # No Color

.PHONY: help install setup start stop restart status logs clean update test health gemini

# Default target
.DEFAULT_GOAL := help

help: ## Display this help message
	@echo "$(GREEN)Okta MCP Server - Native Installation Commands$(NC)"
	@echo ""
	@echo "$(BLUE)Quick Start:$(NC)"
	@echo "  1. $(YELLOW)make install$(NC)   - Run complete installation"
	@echo "  2. $(YELLOW)make start$(NC)     - Start services"
	@echo "  3. $(YELLOW)make status$(NC)    - Check status"
	@echo "  4. $(YELLOW)make gemini$(NC)    - Launch Gemini CLI"
	@echo ""
	@echo "$(BLUE)Available Commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-18s$(NC) %s\n", $$1, $$2}'

# Installation Commands
install: ## Run complete native installation
	@echo "$(GREEN)Starting native installation...$(NC)"
	@chmod +x oneclickinstall.sh
	@./oneclickinstall.sh

setup: ## Setup environment (directories, config)
	@echo "$(GREEN)Setting up environment...$(NC)"
	@mkdir -p $(MCP_DIR)/logs
	@mkdir -p $(MCP_DIR)/.gemini
	@echo "$(GREEN)Environment setup complete$(NC)"

update-mcp: ## Update Okta MCP Server from GitHub
	@echo "$(GREEN)Updating Okta MCP Server...$(NC)"
	@cd $(MCP_DIR) && git pull
	@cd $(MCP_DIR) && $(UV) sync
	@echo "$(GREEN)Update complete$(NC)"

# Service Management
start: ## Start all services
	@echo "$(GREEN)Starting services...$(NC)"
	@sudo systemctl start $(SERVICE_NAME)
	@sleep 2
	@sudo systemctl start $(GATEWAY_SERVICE)
	@echo "$(GREEN)Services started$(NC)"

start-mcp: ## Start only MCP server
	@echo "$(GREEN)Starting MCP server...$(NC)"
	@sudo systemctl start $(SERVICE_NAME)
	@echo "$(GREEN)MCP server started$(NC)"

start-gateway: ## Start only gateway
	@echo "$(GREEN)Starting HTTP gateway...$(NC)"
	@sudo systemctl start $(GATEWAY_SERVICE)
	@echo "$(GREEN)Gateway started on port $(GATEWAY_PORT)$(NC)"

stop: ## Stop all services
	@echo "$(YELLOW)Stopping services...$(NC)"
	@sudo systemctl stop $(GATEWAY_SERVICE)
	@sudo systemctl stop $(SERVICE_NAME)
	@echo "$(GREEN)Services stopped$(NC)"

restart: ## Restart all services
	@echo "$(YELLOW)Restarting services...$(NC)"
	@sudo systemctl restart $(SERVICE_NAME)
	@sleep 2
	@sudo systemctl restart $(GATEWAY_SERVICE)
	@echo "$(GREEN)Services restarted$(NC)"

enable: ## Enable services to start on boot
	@echo "$(GREEN)Enabling auto-start...$(NC)"
	@sudo systemctl enable $(SERVICE_NAME)
	@sudo systemctl enable $(GATEWAY_SERVICE)
	@echo "$(GREEN)Auto-start enabled$(NC)"

disable: ## Disable services from starting on boot
	@echo "$(YELLOW)Disabling auto-start...$(NC)"
	@sudo systemctl disable $(GATEWAY_SERVICE)
	@sudo systemctl disable $(SERVICE_NAME)
	@echo "$(GREEN)Auto-start disabled$(NC)"

# Status and Monitoring
status: ## Check service status
	@echo "$(GREEN)Service Status:$(NC)"
	@echo "$(BLUE)MCP Server:$(NC)"
	@systemctl status $(SERVICE_NAME) --no-pager | head -n 10
	@echo ""
	@echo "$(BLUE)HTTP Gateway:$(NC)"
	@systemctl status $(GATEWAY_SERVICE) --no-pager | head -n 10

health: ## Check service health
	@echo "$(GREEN)Checking health...$(NC)"
	@systemctl is-active --quiet $(SERVICE_NAME) && echo "✅ MCP Server is running" || echo "❌ MCP Server is not running"
	@systemctl is-active --quiet $(GATEWAY_SERVICE) && echo "✅ Gateway is running" || echo "❌ Gateway is not running"
	@curl -s -f http://localhost:$(GATEWAY_PORT) > /dev/null 2>&1 && echo "✅ Gateway responding on port $(GATEWAY_PORT)" || echo "❌ Gateway not responding"

logs: ## View service logs
	@echo "$(GREEN)Recent logs:$(NC)"
	@sudo journalctl -u $(SERVICE_NAME) -u $(GATEWAY_SERVICE) -n 50 --no-pager

logs-mcp: ## View MCP server logs
	@sudo journalctl -u $(SERVICE_NAME) -f

logs-gateway: ## View gateway logs
	@sudo journalctl -u $(GATEWAY_SERVICE) -f

logs-follow: ## Follow all logs in real-time
	@sudo journalctl -u $(SERVICE_NAME) -u $(GATEWAY_SERVICE) -f

# Testing
test: ## Test MCP server directly
	@echo "$(GREEN)Testing MCP server...$(NC)"
	@cd $(MCP_DIR) && echo '{"method": "list_tools"}' | $(UV) run okta-mcp-server

test-gateway: ## Test gateway HTTP endpoint
	@echo "$(GREEN)Testing gateway...$(NC)"
	@curl -v http://localhost:$(GATEWAY_PORT)

test-gemini: ## Test Gemini CLI connection
	@echo "$(GREEN)Testing Gemini CLI...$(NC)"
	@gemini --server okta-mcp-local --version || echo "Gemini CLI not found or not configured"

gemini: ## Launch Gemini CLI
	@echo "$(GREEN)Launching Gemini CLI...$(NC)"
	@echo ""
	@cd $(MCP_DIR) && gemini

# Configuration
check-env: ## Check environment configuration
	@echo "$(GREEN)Checking configuration...$(NC)"
	@[ -f $(MCP_DIR)/.env ] && echo "✅ .env file exists" || echo "❌ .env file missing"
	@[ -f ~/.gemini/settings.json ] && echo "✅ Gemini config exists" || echo "❌ Gemini config missing"
	@which $(PYTHON) > /dev/null && echo "✅ Python 3.13 found" || echo "❌ Python 3.13 not found"
	@which npx > /dev/null && echo "✅ Node.js found" || echo "❌ Node.js not found"

show-config: ## Show current configuration (without secrets)
	@echo "$(GREEN)Current Configuration:$(NC)"
	@[ -f $(MCP_DIR)/.env ] && grep -v "PRIVATE_KEY\|API_KEY" $(MCP_DIR)/.env || echo "No configuration found"

edit-env: ## Edit environment configuration
	@${EDITOR:-nano} $(MCP_DIR)/.env

# Maintenance
clean: ## Clean logs and temporary files
	@echo "$(YELLOW)Cleaning temporary files...$(NC)"
	@rm -f $(MCP_DIR)/logs/*.log.* 2>/dev/null || true
	@echo "$(GREEN)Cleanup complete$(NC)"

uninstall: ## Uninstall services (keeps data)
	@echo "$(RED)Uninstalling services...$(NC)"
	@sudo systemctl stop $(GATEWAY_SERVICE) 2>/dev/null || true
 	@sudo systemctl disable $(GATEWAY_SERVICE) 2>/dev/null || true
 	@sudo rm -f /etc/systemd/system/$(GATEWAY_SERVICE).service
	@sudo systemctl daemon-reload
	@echo "$(GREEN)Services uninstalled (data preserved in $(MCP_DIR))$(NC)"

# Development
dev-run: ## Run MCP server in development mode
	@echo "$(GREEN)Running in development mode...$(NC)"
	@cd $(MCP_DIR) && OKTA_LOG_LEVEL=DEBUG $(UV) run okta-mcp-server

dev-gateway: ## Run gateway in development mode
	@echo "$(GREEN)Running gateway in development mode...$(NC)"
	@cd $(MCP_DIR) && npx supergateway --stdio "$(UV) run okta-mcp-server" --outputTransport streamableHttp --stateful --port $(GATEWAY_PORT)

# Information
info: ## Show installation information
	@echo "$(GREEN)Okta MCP Server Installation Info$(NC)"
	@echo "=================================="
	@echo "📁 Installation: $(MCP_DIR)"
	@echo "🐍 Python: $(PYTHON)"
	@echo "🌐 Gateway Port: $(GATEWAY_PORT)"
	@echo "📝 Config: $(MCP_DIR)/.env"
	@echo "📊 Logs: $(MCP_DIR)/logs/"
	@echo "🤖 Gemini Config: ~/.gemini/settings.json"
	@echo ""
	@$(MAKE) health

version: ## Show component versions
	@echo "$(GREEN)Component Versions:$(NC)"
	@$(PYTHON) --version 2>/dev/null || echo "Python 3.13: not found"
	@node --version 2>/dev/null || echo "Node.js: not found"
	@npx supergateway --version 2>/dev/null || echo "Supergateway: not found"
	@gemini --version 2>/dev/null || echo "Gemini CLI: not found"

# Quick actions
quick-start: install start health ## Complete installation and start
	@echo "$(GREEN)Quick start completed!$(NC)"

quick-test: test test-gateway test-gemini ## Run all tests
	@echo "$(GREEN)All tests completed!$(NC)"
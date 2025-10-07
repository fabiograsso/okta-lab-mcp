#!/bin/bash

# Docker utilities for Okta MCP Server
# Version: 1.1
# Author: Fabio

set -e

# Colors for display
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Utility functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install it: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        log_error "Docker Compose is not installed."
        exit 1
    fi
    
    log_success "All prerequisites are satisfied"
}

# Check .env file (only needed for docker compose)
check_env_file() {
    if [ ! -f ".env" ]; then
        log_warning ".env file not found. Creating from template..."
        create_env_template
        log_warning "Please edit the .env file with your Okta credentials"
        return 1
    fi
    
    # Check required variables
    required_vars=("OKTA_ORG_URL" "OKTA_CLIENT_ID")
    missing_vars=()
        
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        log_error "Missing variables in .env: ${missing_vars[*]}"
        return 1
    fi
    
    log_success ".env configuration valid"
    return 0
}

# Create env template
create_env_template() {    
    if [ ! -f ".env" ]; then
        cp example.env .env
        log_info "Created .env from template"
    fi
}

# Check if okta-mcp-server source exists
check_okta_source() {
    if [ ! -d "okta-mcp-server" ]; then
        log_warning "okta-mcp-server directory not found!"
        log_info "Attempting to clone from GitHub..."
        
        # Try to clone the official repository
        if git clone https://github.com/oktadev/okta-mcp-server.git 2>/dev/null; then
            log_success "Okta MCP Server source cloned successfully"
        else
            log_error "Failed to clone. Please manually add okta-mcp-server source"
            return 1
        fi
    fi
    
    if [ ! -f "okta-mcp-server/pyproject.toml" ]; then
        log_error "Invalid okta-mcp-server directory (missing pyproject.toml)"
        return 1
    fi
    
    log_success "Okta MCP Server source found"
    return 0
}

# Build Docker images
build_images() {
    log_info "Building Docker images..."
    
    # Check source directory
    check_okta_source || return 1
    
    # Build main image
    log_info "Building main Okta MCP Server image..."
    if docker build -t okta-mcp-server:latest .; then
        log_success "Main image built: okta-mcp-server:latest"
    else
        log_error "Failed to build main image"
        return 1
    fi
    
    # Build gateway image
    if [ -f "Dockerfile-gateway" ]; then
        log_info "Building gateway image..."
        if docker build -f Dockerfile-gateway -t okta-mcp-server-gateway:latest .; then
            log_success "Gateway image built: okta-mcp-server-gateway:latest"
        else
            log_error "Failed to build gateway image"
            return 1
        fi
    fi
    
    log_success "All images built successfully"
}

# Start services
start_services() {
    local services=${1:-""}
    
    if [ -n "$services" ]; then
        log_info "Starting service: $services"
    else
        log_info "Starting all services..."
        check_env_file || {
            log_error ".env configuration required for docker compose"
            return 1
        }
    fi
    
    check_okta_source || return 1
    
    if [ -n "$services" ]; then
        docker compose up -d $services
    else
        docker compose up -d
    fi
    
    log_success "Services started"
    
    # Display status
    docker compose ps
}

# Stop services
stop_services() {
    log_info "Stopping services..."
    docker compose down
    log_success "Services stopped"
}

# Display logs
show_logs() {
    local service=${1:-""}
    
    if [ -n "$service" ]; then
        docker compose logs -f "$service"
    else
        docker compose logs -f
    fi
}

# Clean up Docker resources
cleanup() {
    log_info "Cleaning up Docker resources..."
    
    # Stop and remove containers
    docker compose down -v
    
    # Remove local images
    docker rmi okta-mcp-server:latest 2>/dev/null || true
    docker rmi okta-mcp-server-gateway:latest 2>/dev/null || true
    
    # Clean dangling images
    docker image prune -f
    
    log_success "Cleanup completed"
}

# Open shell in container
shell() {
    local service=${1:-okta-mcp-server}
    
    if ! docker compose ps --services | grep -q "^$service$"; then
        log_error "Service $service not found"
        log_info "Available services:"
        docker compose ps --services
        return 1
    fi
    
    log_info "Opening shell in $service..."
    docker compose exec "$service" /bin/bash || docker compose exec "$service" /bin/sh
}

# Run Gemini CLI inside container
gemini() {
    if ! docker compose ps | grep -q "gemini-cli.*Up"; then
        log_error "Gemini CLI service is not running"
        log_info "Start it with: make start-gemini"
        return 1
    fi
    
    log_info "Opening Gemini CLI shell..."
    docker compose exec gemini-cli gemini
}

# Check service health
check_health() {
    log_info "Checking service health..."
    
    # Check if containers are running
    running_services=$(docker compose ps --services --filter "status=running" 2>/dev/null | wc -l)
    
    if [ "$running_services" -eq 1 ]; then
        log_warning "No services are running"
        return 1
    fi
    
    # Check okta-mcp-server
    if docker compose ps | grep -q "okta-mcp-server.*Up"; then
        log_success "okta-mcp-server is running"
    fi
    
    # Check gateway
    if docker compose ps | grep -q "okta-mcp-server-gateway.*Up"; then
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:8000 | grep -q "200\|404"; then
            log_success "Gateway is responding on port 8000"
        else
            log_warning "Gateway is running but not responding on port 8000"
        fi
    fi
    
    # Check Gemini CLI
    if docker compose ps | grep -q "gemini-cli.*Up"; then
        log_success "Gemini CLI container is running"
    fi
}

# Test gateway endpoint
test_gateway() {
    log_info "Testing gateway endpoint..."
    
    if ! docker compose ps | grep -q "okta-mcp-server-gateway.*Up"; then
        log_error "Gateway service is not running"
        log_info "Start it with: make start-gateway"
        return 1
    fi
    
    log_info "Sending test request to http://localhost:8000..."
    
    response=$(curl -s -w "\nHTTP_CODE:%{http_code}" http://localhost:8000 2>/dev/null || echo "FAILED")
    
    if echo "$response" | grep -q "HTTP_CODE:200\|HTTP_CODE:404"; then
        log_success "Gateway is responding correctly"
    else
        log_error "Gateway test failed"
        log_info "Check logs with: make logs-gateway"
    fi
}

# Main function
main() {
    case "$1" in
        "setup")
            check_prerequisites
            setup_directories
            create_env_template
            check_okta_source
            ;;
        "build")
            build_images
            ;;
        "start"|"up")
            shift
            start_services "$@"
            ;;
        "stop"|"down")
            stop_services
            ;;
        "restart")
            stop_services
            shift
            start_services "$@"
            ;;
        "logs")
            shift
            show_logs "$@"
            ;;
        "clean"|"cleanup")
            cleanup
            ;;
        "shell"|"sh")
            shift
            shell "$@"
            ;;
        "status"|"ps")
            docker compose ps
            ;;
        "health")
            check_health
            ;;
        "test-gateway")
            test_gateway
            ;;
        "backup")
            backup_logs
            ;;
        "check-env")
            check_env_file && log_success "Environment configuration is valid"
            ;;
        "check-source")
            check_okta_source && log_success "Source code is present"
            ;;
        *)
            echo "Usage: $0 {setup|build|start|stop|restart|logs|clean|shell|status|health|test-gateway|backup|check-env|check-source}"
            echo ""
            echo "Commands:"
            echo "  setup         - Initial setup (directories, env template, source check)"
            echo "  build         - Build Docker images"
            echo "  start [svc]   - Start services (all or specific)"
            echo "  stop          - Stop all services"
            echo "  restart [svc] - Restart services"
            echo "  logs [svc]    - Display logs"
            echo "  clean         - Clean Docker resources"
            echo "  shell [svc]   - Open shell in container"
            echo "  status        - Display service status"
            echo "  health        - Check service health"
            echo "  test-gateway  - Test gateway HTTP endpoint"
            echo "  backup        - Backup logs"
            echo "  check-env     - Verify .env configuration"
            echo "  check-source  - Verify source code presence"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
#!/bin/bash
# ALMAS LAW Docker Compose - Quick Start Script
# Usage: ./docker-setup.sh [start|stop|logs|health]

set -e

PROJECT_NAME="almas-law"
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
    
    if [ ! -f "$ENV_FILE" ]; then
        print_warn ".env file not found, copying from .env.example"
        if [ ! -f ".env.example" ]; then
            print_error ".env.example not found"
            exit 1
        fi
        cp .env.example .env
        print_warn "Please edit .env with your configuration before starting services"
    fi
    
    print_info "All prerequisites checked"
}

# Start services
start_services() {
    print_info "Starting ALMAS LAW services..."
    docker-compose -f "$COMPOSE_FILE" up -d
    print_info "Services started. Waiting for health checks..."
    sleep 10
    check_health
}

# Stop services
stop_services() {
    print_info "Stopping ALMAS LAW services..."
    docker-compose -f "$COMPOSE_FILE" stop
    print_info "Services stopped"
}

# Show logs
show_logs() {
    SERVICE=${1:-""}
    if [ -n "$SERVICE" ]; then
        docker-compose -f "$COMPOSE_FILE" logs -f "$SERVICE"
    else
        docker-compose -f "$COMPOSE_FILE" logs -f
    fi
}

# Check health status
check_health() {
    print_info "Checking service health status..."
    echo ""
    
    services=("postgres" "qdrant" "neo4j" "redis" "minio" "keycloak")
    
    for service in "${services[@]}"; do
        status=$(docker-compose -f "$COMPOSE_FILE" ps "$service" | grep "$service" | awk '{print $NF}')
        if [ -z "$status" ]; then
            status="Not found"
        fi
        printf "%-15s : %s\n" "$service" "$status"
    done
    
    echo ""
    print_info "Service Access URLs:"
    echo "  PostgreSQL         : localhost:5432"
    echo "  Qdrant REST        : http://localhost:6333"
    echo "  Qdrant gRPC        : localhost:6334"
    echo "  Neo4j Browser      : http://localhost:7474"
    echo "  Neo4j Bolt         : bolt://localhost:7687"
    echo "  Redis              : localhost:6379"
    echo "  MinIO API          : http://localhost:9000"
    echo "  MinIO Console      : http://localhost:9001"
    echo "  Keycloak           : http://localhost:8080"
}

# Clean up (remove containers and volumes)
cleanup() {
    print_warn "Removing all containers and volumes..."
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        docker-compose -f "$COMPOSE_FILE" down -v
        print_info "Cleanup complete"
    else
        print_info "Cleanup cancelled"
    fi
}

# Main script logic
main() {
    case "${1:-start}" in
        start)
            check_prerequisites
            start_services
            ;;
        stop)
            stop_services
            ;;
        logs)
            show_logs "$2"
            ;;
        health)
            check_health
            ;;
        restart)
            stop_services
            sleep 2
            start_services
            ;;
        clean)
            cleanup
            ;;
        *)
            echo "ALMAS LAW Docker Compose Management"
            echo ""
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  start              Start all services (default)"
            echo "  stop               Stop all services"
            echo "  restart            Restart all services"
            echo "  logs [service]     Show logs (optionally for specific service)"
            echo "  health             Check service health status"
            echo "  clean              Remove all containers and volumes"
            echo ""
            echo "Examples:"
            echo "  $0 start"
            echo "  $0 logs postgres"
            echo "  $0 health"
            ;;
    esac
}

# Run main function
main "$@"

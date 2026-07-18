# ALMAS LAW Docker Compose Setup Guide

## Overview

This Docker Compose configuration deploys the complete ALMAS LAW infrastructure stack with all required services for development and production environments. The setup includes proper network isolation, persistent volumes, and environment variable management.

## Services Included

### 1. **PostgreSQL 16 with pgvector**
- **Purpose**: Primary database for legal documents, citations, and system data
- **Port**: 5432
- **pgvector Extension**: Enables vector similarity search for embeddings
- **Data Persistence**: `postgres_data` volume
- **Health Check**: Enabled
- **Init Script**: `init-scripts/postgres/01-init.sql` - Creates schemas, tables, and indexes

### 2. **Qdrant Vector Database**
- **Purpose**: Vector embeddings storage for semantic search over legal documents
- **Ports**: 
  - HTTP: 6333
  - gRPC: 6334
- **Configuration**: `config/qdrant_config.yaml`
- **Data Persistence**: `qdrant_data` volume
- **Health Check**: Enabled via HTTP health endpoint
- **Features**: RESTful API, gRPC support, snapshot management

### 3. **Neo4j Graph Database**
- **Purpose**: Graph database for storing legal citations, relationships, and precedents
- **Ports**:
  - HTTP Browser: 7474
  - Bolt Protocol: 7687
- **Features**: APOC procedures enabled for import/export
- **Data Persistence**: `neo4j_data` and `neo4j_logs` volumes
- **Health Check**: Enabled
- **Access**: Via Neo4j Browser at http://localhost:7474

### 4. **Redis 7**
- **Purpose**: In-memory cache and session store for performance optimization
- **Port**: 6379
- **Features**: 
  - Password authentication
  - AOF persistence enabled
  - Alpine-based minimal image
- **Data Persistence**: `redis_data` volume
- **Health Check**: Enabled

### 5. **MinIO Object Storage**
- **Purpose**: S3-compatible object storage for documents, files, and media
- **Ports**:
  - API: 9000
  - Console: 9001
- **Console Access**: http://localhost:9001
- **Default Credentials**: Set via environment variables
- **Data Persistence**: `minio_data` volume
- **Health Check**: Enabled

### 6. **Keycloak**
- **Purpose**: Identity and access management, OpenID Connect/OAuth2 provider
- **Port**: 8080
- **Admin Console**: http://localhost:8080
- **Database Backend**: PostgreSQL (connects to main postgres service)
- **Features**: Single sign-on, role-based access control, token management
- **Data Persistence**: `keycloak_data` volume
- **Health Check**: Enabled

## Network Architecture

All services are connected through an isolated bridge network:
- **Network Name**: `almas-network`
- **Subnet**: 172.25.0.0/16
- **Benefits**: Services communicate via container names (DNS), isolated from host network except exposed ports

## Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- At least 4GB RAM available
- 20GB free disk space

## Quick Start

### 1. Environment Configuration

```bash
# Copy and customize environment variables
cp .env .env.local

# Edit .env.local with your secure passwords
# IMPORTANT: Change all default passwords for production!
```

### 2. Start All Services

```bash
# Start services in background
docker-compose up -d

# Or with logs output
docker-compose up
```

### 3. Verify Services Are Running

```bash
# Check service status
docker-compose ps

# Check specific service logs
docker-compose logs postgres
docker-compose logs keycloak
```

### 4. Access Services

| Service | URL | Default Credentials |
|---------|-----|-------------------|
| PostgreSQL | localhost:5432 | See `.env` file |
| Qdrant | http://localhost:6333 | API Key in `.env` |
| Neo4j | http://localhost:7474 | neo4j / (set in `.env`) |
| Redis | localhost:6379 | Password in `.env` |
| MinIO | http://localhost:9001 | minioadmin / (set in `.env`) |
| Keycloak | http://localhost:8080 | admin / (set in `.env`) |

## Environment Variables

All configuration is managed through `.env` file with these key variables:

```env
# PostgreSQL
POSTGRES_DB=almas_db
POSTGRES_USER=almas_admin
POSTGRES_PASSWORD=your_secure_password
POSTGRES_PORT=5432

# Qdrant
QDRANT_API_KEY=your_api_key
QDRANT_PORT=6333

# Neo4j
NEO4J_USER=neo4j
NEO4J_PASSWORD=your_secure_password

# Redis
REDIS_PASSWORD=your_secure_password

# MinIO
MINIO_ROOT_USER=minioadmin
MINIO_ROOT_PASSWORD=your_secure_password

# Keycloak
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=your_secure_password
```

## Data Persistence

All services use named Docker volumes for data persistence:

- `postgres_data` - PostgreSQL database files
- `qdrant_data` - Vector embeddings
- `neo4j_data` - Graph database data
- `neo4j_logs` - Neo4j logs
- `redis_data` - Redis cache data
- `minio_data` - Object storage files
- `keycloak_data` - Keycloak realm and configuration

Volumes are automatically created and persisted across container restarts.

## Common Operations

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f postgres

# Last 100 lines
docker-compose logs --tail=100 keycloak
```

### Stop Services

```bash
# Stop but preserve volumes
docker-compose stop

# Stop and remove containers
docker-compose down

# Stop, remove containers, and volumes (CAUTION!)
docker-compose down -v
```

### Database Backups

```bash
# PostgreSQL backup
docker-compose exec postgres pg_dump -U postgres almas_db > backup.sql

# Restore from backup
docker-compose exec -T postgres psql -U postgres almas_db < backup.sql
```

### Connect to Services

```bash
# PostgreSQL CLI
docker-compose exec postgres psql -U postgres -d almas_db

# Redis CLI
docker-compose exec redis redis-cli -a your_password

# Neo4j Cypher
docker-compose exec neo4j cypher-shell -u neo4j -p your_password

# MinIO client (mc)
docker-compose exec minio mc alias set minio http://localhost:9000 minioadmin password
```

## Production Deployment Considerations

### Security Recommendations

1. **Change All Default Passwords**: Never use default credentials in production
2. **Use `.env.local` for Secrets**: Keep sensitive data out of version control
3. **Enable HTTPS**: Use reverse proxy (nginx/traefik) with SSL/TLS
4. **Network Security**: Use firewall rules to restrict access
5. **Resource Limits**: Set memory/CPU limits in docker-compose
6. **Backup Strategy**: Implement automated backup procedures
7. **Monitoring**: Deploy observability stack (Prometheus, Grafana, etc.)

### Production Modifications

```yaml
# Add resource limits
services:
  postgres:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G

# Add restart policies
  postgres:
    restart: always  # Changed from unless-stopped
```

### High Availability Setup

For production, consider:
- PostgreSQL replication/clustering
- Redis Sentinel for high availability
- Neo4j clustering
- Multiple Keycloak instances with load balancing
- S3-compatible backup for MinIO

## Troubleshooting

### Services won't start

```bash
# Check logs
docker-compose logs postgres

# Verify disk space
docker system df

# Rebuild images
docker-compose down
docker-compose pull
docker-compose up
```

### Connection refused errors

```bash
# Verify services are running
docker-compose ps

# Check network
docker network inspect almas-network

# Test connectivity between containers
docker-compose exec postgres ping qdrant
```

### Keycloak fails to connect to PostgreSQL

1. Ensure `postgres` service is healthy before `keycloak` starts
2. Verify database credentials match in environment variables
3. Check that the `keycloak` database exists (created by init script)

### Slow performance

1. Increase Docker memory allocation
2. Reduce QDRANT indexing threads: `"QDRANT_INDEXING_THREADS=2"`
3. Enable Redis AOF rewrite: `redis-server --auto-aof-rewrite-percentage 100`
4. Monitor with: `docker stats`

## Maintenance

### Regular Tasks

1. **Weekly**: Review and archive audit logs
2. **Monthly**: Verify backups, update base images
3. **Quarterly**: Security audit, dependency updates
4. **Annually**: Disaster recovery testing

### Update Images

```bash
# Pull latest images
docker-compose pull

# Recreate services with new images
docker-compose up -d
```

## Integration with ALMAS LAW Application

### PostgreSQL Connection String

```
postgresql://postgres:password@postgres:5432/almas_db
```

### Qdrant Client Initialization

```python
from qdrant_client import QdrantClient

client = QdrantClient(
    host="qdrant",
    port=6333,
    api_key="your_api_key"
)
```

### Neo4j Connection String

```
bolt://neo4j:password@neo4j:7687
```

### Redis Connection

```
redis://default:password@redis:6379/0
```

### MinIO Client Setup

```python
from minio import Minio

client = Minio(
    "minio:9000",
    access_key="minioadmin",
    secret_key="password",
    secure=False
)
```

### Keycloak Integration

- **Admin API**: http://keycloak:8080/auth
- **OIDC Discovery**: http://keycloak:8080/.well-known/openid-configuration
- **Token Endpoint**: http://keycloak:8080/auth/realms/master/protocol/openid-connect/token

## Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Qdrant Documentation](https://qdrant.tech/documentation/)
- [Neo4j Documentation](https://neo4j.com/docs/)
- [Redis Documentation](https://redis.io/documentation)
- [MinIO Documentation](https://min.io/docs/minio/linux/index.html)
- [Keycloak Documentation](https://www.keycloak.org/documentation.html)

## Support

For issues or questions, please refer to:
1. Individual service documentation
2. ALMAS LAW project issues
3. Docker and Compose troubleshooting guides

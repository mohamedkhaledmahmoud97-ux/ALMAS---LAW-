# ALMAS LAW Docker Compose - Quick Reference Guide

## 📦 What's Included

This Docker Compose setup provides a complete, production-ready infrastructure for the ALMAS LAW platform with:

### Services
- **PostgreSQL 16** with pgvector for vector embeddings and relational data
- **Qdrant** vector database for semantic search over legal documents
- **Neo4j** graph database for legal citations and relationships
- **Redis 7** for caching and session management
- **MinIO** S3-compatible object storage for documents
- **Keycloak** identity and access management with OAuth2/OIDC

### Features
✅ Proper network isolation (bridge network: 172.25.0.0/16)  
✅ Environment variables from `.env` file  
✅ Persistent volumes for all data  
✅ Health checks for all services  
✅ Production configuration file (`docker-compose.prod.yml`)  
✅ Comprehensive documentation  
✅ Database initialization scripts  
✅ Makefile for common operations  
✅ Service startup shell script  

## 🚀 Quick Start

### 1. Initial Setup
```bash
# Copy environment template
cp .env.example .env

# Edit with your credentials
# IMPORTANT: Change all "ChangeMe_" passwords before production!
nano .env
```

### 2. Start Services
```bash
# Using Docker Compose directly
docker-compose up -d

# Or using Make (recommended)
make up

# Or using shell script
bash docker-setup.sh start
```

### 3. Verify Services
```bash
make status
# or
docker-compose ps
```

### 4. Access Services
| Service | URL/Host | Port |
|---------|----------|------|
| PostgreSQL | localhost | 5432 |
| Qdrant REST | http://localhost:6333 | |
| Qdrant gRPC | localhost:6334 | |
| Neo4j Browser | http://localhost:7474 | |
| Neo4j Bolt | bolt://localhost:7687 | |
| Redis | localhost:6379 | |
| MinIO API | http://localhost:9000 | |
| MinIO Console | http://localhost:9001 | |
| Keycloak | http://localhost:8080 | |

## 📁 File Structure

```
ALMAS---LAW-/
├── docker-compose.yml           # Main development configuration
├── docker-compose.prod.yml      # Production configuration with resources limits
├── .env                         # Environment variables (CREATE FROM .env.example)
├── .env.example                 # Template with all variables
├── .dockerignore               # Docker build exclusions
├── docker-setup.sh             # Bash script for service management
├── Makefile                    # Make targets for common operations
├── DOCKER_SETUP.md             # Comprehensive documentation
├── init-scripts/
│   ├── postgres/
│   │   └── 01-init.sql        # PostgreSQL initialization (schemas, tables, indexes)
│   └── neo4j/                 # Neo4j scripts (placeholder)
└── config/
    ├── postgresql.conf        # PostgreSQL optimization
    └── qdrant_config.yaml     # Qdrant configuration
```

## 📋 Using Make Commands

```bash
# Start services
make up

# Stop services
make down

# Restart services
make restart

# View logs (all or specific service)
make logs
make logs-postgres
make logs-keycloak

# Check status
make status

# Health checks
make health-check

# Database operations
make backup-postgres          # Backup database
make restore-postgres         # Restore from backup
make db-init                  # Run initialization scripts

# Shell access
make shell-postgres           # PostgreSQL CLI
make shell-redis              # Redis CLI
make shell-neo4j              # Neo4j Cypher shell

# Production
make up-prod                  # Start with production config
make down-prod                # Stop production services

# Maintenance
make clean                    # Remove all containers/volumes (WARNING!)
make prune                    # Remove unused Docker resources
make pull                     # Update images to latest
```

## 🔧 Shell Script Commands

```bash
bash docker-setup.sh start    # Start services
bash docker-setup.sh stop     # Stop services
bash docker-setup.sh restart  # Restart services
bash docker-setup.sh logs     # Show logs
bash docker-setup.sh health   # Check health
bash docker-setup.sh clean    # Remove containers and volumes
```

## 🔐 Security Best Practices

### Development Environment
- Use the provided `.env` with development passwords
- Keep `.env.local` out of version control (already in .gitignore)
- Don't expose services to the internet

### Production Deployment
1. **Generate Strong Passwords**
   ```bash
   openssl rand -base64 32
   ```

2. **Use `docker-compose.prod.yml`**
   - Includes resource limits
   - Production logging configuration
   - Optimized database parameters

3. **Network Security**
   - Use a reverse proxy (nginx, traefik)
   - Enable SSL/TLS for all connections
   - Restrict access with firewall rules

4. **Credentials Management**
   - Use Docker secrets or external secret management
   - Never hardcode credentials
   - Rotate passwords regularly

5. **Backup Strategy**
   ```bash
   make backup-postgres          # Regular backups
   docker volume ls             # Check volume names
   # Implement offsite backup procedures
   ```

## 📊 Common Operations

### View Service Logs
```bash
# All services
docker-compose logs -f

# Specific service (last 50 lines)
docker-compose logs --tail=50 postgres

# Follow logs in real-time
docker-compose logs -f keycloak
```

### Database Access
```bash
# PostgreSQL
docker-compose exec postgres psql -U postgres -d almas_db

# Redis
docker-compose exec redis redis-cli -a $REDIS_PASSWORD

# Neo4j (via HTTP)
curl -u neo4j:password http://localhost:7474/db/neo4j/info

# MinIO Console
# Visit http://localhost:9001 in browser
```

### Performance Monitoring
```bash
# Docker statistics
docker stats

# Specific service resource usage
docker stats almas-postgres

# Disk usage
docker system df
```

### Health Verification
```bash
# PostgreSQL
docker-compose exec postgres pg_isready -U postgres

# Qdrant
curl http://localhost:6333/health

# Neo4j
curl http://localhost:7474/db/neo4j/info

# Redis
docker-compose exec redis redis-cli ping

# MinIO
curl http://localhost:9000/minio/health/live
```

## 🐛 Troubleshooting

### Service Won't Start
```bash
# Check service logs
docker-compose logs postgres

# Verify ports aren't in use
netstat -tulpn | grep 5432

# Check disk space
docker system df
```

### Keycloak Database Connection Failed
```bash
# Ensure postgres is healthy first
docker-compose logs postgres

# Verify database exists
docker-compose exec postgres psql -U postgres -l
```

### Out of Disk Space
```bash
# Clean up Docker resources
make prune

# Remove specific volume (WARNING: data loss!)
docker volume rm almas-law_postgres_data
```

### Service Crashes After Restart
```bash
# Check logs
docker-compose logs service_name

# Rebuild containers
docker-compose down
docker-compose pull
docker-compose up -d
```

## 📚 Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [PostgreSQL + pgvector](https://github.com/pgvector/pgvector)
- [Qdrant Docs](https://qdrant.tech/documentation/)
- [Neo4j Docs](https://neo4j.com/docs/)
- [Redis Docs](https://redis.io/docs/)
- [MinIO Docs](https://min.io/docs/minio/linux/index.html)
- [Keycloak Docs](https://www.keycloak.org/documentation.html)

## 📝 Configuration Reference

### PostgreSQL Environment Variables
- `POSTGRES_DB` - Database name (default: almas_db)
- `POSTGRES_USER` - Database user (default: postgres)
- `POSTGRES_PASSWORD` - Database password (REQUIRED to change)

### Qdrant Environment Variables
- `QDRANT_API_KEY` - API authentication key
- `QDRANT_PORT` - REST API port (default: 6333)
- `QDRANT_GRPC_PORT` - gRPC port (default: 6334)

### Neo4j Environment Variables
- `NEO4J_USER` - Username (default: neo4j)
- `NEO4J_PASSWORD` - Password (REQUIRED to change)

### Redis Environment Variables
- `REDIS_PASSWORD` - Redis password (REQUIRED to change)

### MinIO Environment Variables
- `MINIO_ROOT_USER` - Root username
- `MINIO_ROOT_PASSWORD` - Root password (REQUIRED to change)

### Keycloak Environment Variables
- `KEYCLOAK_ADMIN` - Admin username
- `KEYCLOAK_ADMIN_PASSWORD` - Admin password (REQUIRED to change)
- `KEYCLOAK_DB` - Database name (default: keycloak)

## 💾 Data Backup and Recovery

### Automated Backup
```bash
# Create backup directory
mkdir -p ./backups

# PostgreSQL backup
docker-compose exec -T postgres pg_dump -U postgres almas_db > ./backups/almas_$(date +%Y%m%d_%H%M%S).sql

# Using Make
make backup-postgres
```

### Restore from Backup
```bash
# Restore database
docker-compose exec -T postgres psql -U postgres almas_db < ./backups/almas_20240715_120000.sql

# Using Make
make restore-postgres
```

## 🎯 Next Steps

1. ✅ Copy `.env.example` to `.env`
2. ✅ Update passwords in `.env`
3. ✅ Run `make up` to start services
4. ✅ Run `make status` to verify
5. ✅ Access services via provided URLs
6. ✅ Review `DOCKER_SETUP.md` for detailed documentation
7. ✅ Set up regular backups
8. ✅ Configure monitoring and logging for production

## 📞 Support

For issues:
1. Check `DOCKER_SETUP.md` for detailed troubleshooting
2. Review service logs: `make logs`
3. Verify service health: `make health-check`
4. Check individual service documentation
5. Review Docker and Docker Compose documentation

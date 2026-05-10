# TravelBooking — Local Development Setup Guide (Docker Compose)

This guide explains how to run the entire TravelBooking application on your local machine using Docker Compose. No GKE, no cloud — everything runs on your laptop.

---

## What is Docker Compose?

Docker Compose is a tool that lets you run **multiple Docker containers together** with a single command. Instead of starting each service one by one, you define all services in a `docker-compose.yml` file and run them all at once.

**In simple terms:** One command starts the entire application — database, cache, 5 backend services, frontend, and nginx gateway.

---

## Architecture (Local Setup)

```
Browser → http://localhost:8080
              │
              ▼
       ┌──────────────┐
       │    Nginx      │  port 8080
       │   (Gateway)   │
       └──────┬───────┘
              │
    ┌─────────┼─────────────────────────────────────┐
    │         │         │         │         │        │
    ▼         ▼         ▼         ▼         ▼        ▼
┌────────┐┌────────┐┌────────┐┌────────┐┌────────┐┌────────┐
│Frontend││ User   ││Search  ││Booking ││Payment ││Notify  │
│  :80   ││ :3001  ││ :3002  ││ :3003  ││ :3004  ││ :3005  │
└────────┘└────┬───┘└───┬────┘└───┬────┘└───┬────┘└───┬────┘
               │        │        │        │        │
               ▼        ▼        ▼        ▼        ▼
          ┌──────────────────────────────────────────┐
          │              PostgreSQL :5432             │
          │  (userdb, searchdb, bookingdb,            │
          │   paymentdb, notificationdb)              │
          └──────────────────────────────────────────┘
          ┌──────────────────────────────────────────┐
          │              Redis :6379                  │
          │  (caching for search & notifications)     │
          └──────────────────────────────────────────┘
```

---

## What Gets Created

| # | Container | Image | Port | Purpose |
|---|-----------|-------|------|---------|
| 1 | `postgres` | postgres:15-alpine | 5432 | Database — stores all application data in 5 databases |
| 2 | `redis` | redis:7-alpine | 6379 | Cache — speeds up search results |
| 3 | `user-service` | Built from ./user-service | 3001 | User registration, login, profiles |
| 4 | `search-service` | Built from ./search-service | 3002 | Search flights and hotels |
| 5 | `booking-service` | Built from ./booking-service | 3003 | Create and manage bookings |
| 6 | `payment-service` | Built from ./payment-service | 3004 | Process payments |
| 7 | `notification-service` | Built from ./notification-service | 3005 | Send notifications |
| 8 | `react-frontend` | Built from ./frontend | 3000 | React UI (website) |
| 9 | `nginx-gateway` | nginx:alpine | 8080 | Reverse proxy — routes traffic to correct service |

---

## Prerequisites

### 1. Docker Engine

Docker must be installed and running on your machine.

**Check if Docker is installed:**
```bash
docker --version
# Expected: Docker version 24.x or higher
```

**Check if Docker is running:**
```bash
docker ps
# Should show an empty table (no error)
```

**Install Docker (if not installed):**

- **Ubuntu/Debian:**
  ```bash
  sudo apt-get update
  sudo apt-get install -y docker.io
  sudo usermod -aG docker $USER
  # Log out and log back in for group change to take effect
  ```

- **Mac:** Download [Docker Desktop](https://www.docker.com/products/docker-desktop/)

- **Windows:** Download [Docker Desktop](https://www.docker.com/products/docker-desktop/)

### 2. Docker Compose

Docker Compose plugin must be installed.

**Check if Docker Compose is installed:**
```bash
docker compose version
# Expected: Docker Compose version v2.x.x
```

**Install Docker Compose (if not installed):**
```bash
mkdir -p ~/.docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64" \
  -o ~/.docker/cli-plugins/docker-compose
chmod +x ~/.docker/cli-plugins/docker-compose
```

### 3. Git (to clone the repository)

```bash
git --version
# Expected: git version 2.x.x
```

### 4. Minimum System Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| **RAM** | 4 GB | 8 GB |
| **CPU** | 2 cores | 4 cores |
| **Disk** | 5 GB free | 10 GB free |

### 5. Ports Must Be Available

These ports must NOT be in use by other applications:

| Port | Used By |
|------|---------|
| 8080 | Nginx Gateway (main entry point) |
| 3000 | Frontend (direct access) |
| 3001 | User Service |
| 3002 | Search Service |
| 3003 | Booking Service |
| 3004 | Payment Service |
| 3005 | Notification Service |
| 5432 | PostgreSQL |
| 6379 | Redis |

**Check if a port is in use:**
```bash
sudo lsof -i :8080
# If output shows a process, that port is occupied
```

---

## Step 1: Clone the Repository

```bash
git clone https://github.com/vijaygiduthuri/travelbooking-app.git
cd travelbooking-app
```

Or if you already have the code:
```bash
cd /path/to/travelbooking_app
```

---

## Step 2: Start the Application

```bash
docker compose up -d --build
```

**What each flag means:**
- `up` — create and start all containers
- `-d` — run in detached mode (background), so your terminal is free
- `--build` — rebuild Docker images from source code (use this when code changes)

**First run takes 3-5 minutes** (downloading base images and building all services). Subsequent runs are much faster because Docker caches layers.

---

## Step 3: Check Everything is Running

```bash
docker compose ps
```

**Expected output — all containers should show `Up` and `healthy`:**
```
NAME                   STATUS                  PORTS
postgres               Up (healthy)            0.0.0.0:5432->5432/tcp
redis                  Up (healthy)            0.0.0.0:6379->6379/tcp
user-service           Up (healthy)            0.0.0.0:3001->3001/tcp
search-service         Up (healthy)            0.0.0.0:3002->3002/tcp
booking-service        Up (healthy)            0.0.0.0:3003->3003/tcp
payment-service        Up (healthy)            0.0.0.0:3004->3004/tcp
notification-service   Up (healthy)            0.0.0.0:3005->3005/tcp
react-frontend         Up                      0.0.0.0:3000->80/tcp
nginx-gateway          Up                      0.0.0.0:8080->80/tcp
```

> **Note:** Backend services take about 30-40 seconds to become `healthy` because they wait for PostgreSQL to be ready first.

---

## Step 4: Access the Application

Open your browser and go to:

### Main Application (via Nginx Gateway)
**http://localhost:8080**

This is the recommended way — Nginx routes all traffic like the GKE Gateway does in production.

| URL | What It Shows |
|-----|-------------|
| http://localhost:8080/ | Home page (redirects to search) |
| http://localhost:8080/login | Login page |
| http://localhost:8080/register | Registration page |
| http://localhost:8080/search | Search flights and hotels |
| http://localhost:8080/my-trips | Your bookings |

### Direct Frontend Access (without Nginx)
**http://localhost:3000**

### Direct API Access (for testing/debugging)

| Service | Direct URL | Example |
|---------|-----------|---------|
| User Service | http://localhost:3001 | `curl http://localhost:3001/health` |
| Search Service | http://localhost:3002 | `curl http://localhost:3002/api/search/flights?from=NYC&to=LAX` |
| Booking Service | http://localhost:3003 | `curl http://localhost:3003/health` |
| Payment Service | http://localhost:3004 | `curl http://localhost:3004/health` |
| Notification Service | http://localhost:3005 | `curl http://localhost:3005/health` |

---

## Common Commands

### Start the Application

```bash
# Start all services (first time or after code changes)
docker compose up -d --build

# Start all services (no code changes, faster)
docker compose up -d
```

### Stop the Application

```bash
# Stop all containers (data is preserved)
docker compose down

# Stop all containers AND delete all data (PostgreSQL, Redis)
docker compose down -v
```

### View Logs

```bash
# View logs from all services
docker compose logs -f

# View logs from a specific service
docker compose logs -f user-service
docker compose logs -f postgres
docker compose logs -f nginx

# View last 50 lines of logs
docker compose logs --tail=50 user-service
```

### Restart a Single Service

```bash
# Restart user-service (e.g., after code change)
docker compose restart user-service

# Rebuild and restart a single service
docker compose up -d --build user-service
```

### Check Container Status

```bash
# Show running containers
docker compose ps

# Show resource usage (CPU, memory)
docker stats --no-stream
```

### Access a Container Shell

```bash
# Open a shell inside a container
docker compose exec user-service sh
docker compose exec postgres psql -U postgres

# Run a single command inside a container
docker compose exec postgres psql -U postgres -d userdb -c "SELECT * FROM users;"
```

### Clean Up Everything

```bash
# Stop and remove everything (containers, networks, volumes, images)
docker compose down -v --rmi all

# Remove unused Docker resources
docker system prune -f
```

---

## Database Access

### Connect to PostgreSQL

```bash
docker compose exec postgres psql -U postgres
```

Inside the `psql` shell:
```sql
-- List all databases
\l

-- Connect to a database
\c userdb

-- Show tables
\dt

-- Query users
SELECT * FROM users;

-- Switch to another database
\c searchdb
SELECT * FROM flights;
SELECT * FROM hotels;

-- Exit
\q
```

### Quick Queries

```bash
# See all registered users
docker compose exec postgres psql -U postgres -d userdb -c "SELECT id, name, email FROM users;"

# See all flights
docker compose exec postgres psql -U postgres -d searchdb -c "SELECT flight_number, airline, origin, destination, price FROM flights;"

# See all hotels
docker compose exec postgres psql -U postgres -d searchdb -c "SELECT name, city, rating, price_per_night FROM hotels;"

# See all bookings
docker compose exec postgres psql -U postgres -d bookingdb -c "SELECT id, type, status, total_amount FROM bookings;"

# See all payments
docker compose exec postgres psql -U postgres -d paymentdb -c "SELECT id, amount, status, transaction_id FROM payments;"
```

---

## How Nginx Routes Traffic

Nginx acts as a reverse proxy — it receives all requests on port 8080 and routes them to the correct service:

| Request Path | Routed To | Port |
|-------------|-----------|------|
| `/api/users/*` | user-service | 3001 |
| `/api/search/*` | search-service | 3002 |
| `/api/bookings/*` | booking-service | 3003 |
| `/api/payments/*` | payment-service | 3004 |
| `/api/notifications/*` | notification-service | 3005 |
| `/*` (everything else) | react-frontend | 80 |

This is the same routing pattern used by the GKE Gateway in production.

---

## Environment Variables

You can customize the setup using environment variables. Create a `.env` file in the project root:

```bash
# .env (optional — defaults are used if not set)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
JWT_SECRET=changeme-use-a-strong-secret-in-production
```

Or pass them inline:
```bash
POSTGRES_PASSWORD=mypassword docker compose up -d
```

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_USER` | `postgres` | PostgreSQL username |
| `POSTGRES_PASSWORD` | `postgres` | PostgreSQL password |
| `JWT_SECRET` | `changeme-use-a-strong-secret-in-production` | Secret key for JWT tokens |

---

## Troubleshooting

### Container keeps restarting (CrashLoopBackOff equivalent)

Check the logs:
```bash
docker compose logs user-service
```

Common causes:
- PostgreSQL not ready yet — wait 30 seconds and check again
- Wrong database name — check `DB_NAME` in docker-compose.yml
- Port already in use — stop the conflicting process

### "Port already in use" error

Find what's using the port:
```bash
sudo lsof -i :8080
```

Kill the process:
```bash
sudo kill -9 <PID>
```

Or change the port in `docker-compose.yml`:
```yaml
ports:
  - "9090:80"  # Change 8080 to 9090
```

### Database is empty after restart

If you used `docker compose down -v`, the `-v` flag deletes all volumes (including database data). Use `docker compose down` (without `-v`) to preserve data.

### Frontend shows old version after code change

Rebuild the frontend:
```bash
docker compose up -d --build react-frontend nginx
```

### "Permission denied" on Docker

Add your user to the Docker group:
```bash
sudo usermod -aG docker $USER
```

Then log out and log back in, or use:
```bash
sg docker -c "docker compose up -d"
```

### Services can't connect to each other

Make sure all services are on the same network. Check:
```bash
docker network inspect travelbooking_app_travel-booking-network
```

---

## Local vs Production Comparison

| Aspect | Local (Docker Compose) | Production (GKE) |
|--------|----------------------|-------------------|
| **Entry point** | Nginx on port 8080 | GKE Gateway with static IP |
| **Routing** | Nginx reverse proxy | HTTPRoute resources |
| **Database** | Single PostgreSQL container | PostgreSQL StatefulSet with PVC |
| **Cache** | Single Redis container | Redis Deployment |
| **Scaling** | Single instance per service | HPA autoscaling (1-5 replicas) |
| **SSL/TLS** | None (HTTP only) | Google-managed certificate |
| **Domain** | localhost | vijaygiduthuri.in |
| **Monitoring** | Docker stats / logs | Prometheus + Grafana |
| **CI/CD** | Manual `docker compose up` | Jenkins pipeline |

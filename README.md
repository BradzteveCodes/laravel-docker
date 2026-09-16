# Production-Ready Docker Architecture for Laravel

This document defines the target production Docker architecture for a Laravel + Vue/Vite application, based on the Dockerized Laravel repository being studied and the existing Laragon Nginx reverse-proxy/load-balancer approach.

---

## 1. Complete Production Architecture

```text
                              INTERNET
                                  │
                                  ▼
                         ┌─────────────────┐
                         │   EDGE NGINX    │
                         │ HTTPS / TLS     │
                         │ Proxy / LB      │
                         │ Security        │
                         └────────┬────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │  DOCKER NETWORK │
                         └────────┬────────┘
                                  │
        ┌───────────────┬─────────┼──────────┬───────────────┐
        │               │         │          │               │
        ▼               ▼         ▼          ▼               ▼
     NGINX             APP      REDIS      MYSQL           REVERB
        │               │         │          │               │
        │               │         │          │               │
        └──────────────►│         │          │               │
                        │         │          │               │
                        ▼         ▼          ▼               │
                     LARAVEL   CACHE      DATABASE            │
                        │                                  WebSocket
              ┌─────────┼──────────┐                         ▲
              │         │          │                         │
              ▼         ▼          ▼                         │
          HORIZON   SCHEDULER   STORAGE                      │
              │         │                                    │
              ▼         ▼                                    │
            JOBS    CRON/TASKS ──────────────────────────────┘


                 BUILD PIPELINE
                      │
                  Node/Vite
                      │
                 npm run build
                      │
                      ▼
                public/build
                      │
                      ▼
                    NGINX
```

---

## 2. Detailed Network / Server Architecture

```text
                                  INTERNET / LAN
                                         │
                                         ▼
                              ┌─────────────────────┐
                              │   EDGE NGINX         │
                              │   Reverse Proxy      │
                              │                     │
                              │ • HTTP → HTTPS      │
                              │ • SSL/TLS           │
                              │ • Access control    │
                              │ • Security headers  │
                              │ • Load balancing    │
                              │ • Rate limiting     │
                              └──────────┬──────────┘
                                         │
                         ┌───────────────┴───────────────┐
                         │                               │
                         ▼                               ▼
                   PRIMARY APP                      BACKUP APP
                Docker server                    192.168.1.113
                         │
                         ▼
               ┌───────────────────┐
               │   Docker Network  │
               │     internal      │
               └─────────┬─────────┘
                         │
          ┌──────────────┼───────────────────────┐
          │              │                       │
          ▼              ▼                       ▼
   ┌────────────┐  ┌────────────┐         ┌────────────┐
   │   NGINX    │  │   PHP-FPM  │         │    VITE    │
   │ app web    │  │  Laravel   │         │ build only │
   └─────┬──────┘  └─────┬──────┘         └────────────┘
         │               │
         └───────┬───────┘
                 ▼
           ┌──────────────┐
           │   LARAVEL    │
           │ Application  │
           └──────┬───────┘
                  │
        ┌─────────┼───────────┬─────────────┐
        │         │           │             │
        ▼         ▼           ▼             ▼
     MySQL      Redis       Queue        Scheduler
        │         │           │             │
        │         │           ▼             ▼
        │         │       Worker/Horizon  schedule:work
        │         │
        │         └──── cache / locks / queue
        │
        ▼
   Persistent DB
```

---

## 3. Complete Production File Structure

```text
laravel-app/
│
├── app/                              ← Laravel application
├── bootstrap/
├── config/
├── database/
├── public/
├── resources/
├── routes/
├── storage/
├── tests/
│
├── docker/
│   │
│   ├── edge-nginx/                  ← PUBLIC EDGE / GATEWAY
│   │   ├── default.conf
│   │   └── snippets/
│   │       ├── security.conf
│   │       ├── proxy.conf
│   │       └── rate-limit.conf
│   │
│   ├── nginx/                       ← LARAVEL WEB SERVER
│   │   └── default.conf
│   │
│   ├── php/                         ← PHP / PHP-FPM
│   │   ├── php.ini
│   │   └── www.conf
│   │
│   ├── mysql/                       ← MYSQL
│   │   └── my.cnf
│   │
│   ├── redis/                       ← REDIS
│   │   └── redis.conf
│   │
│   ├── horizon/                     ← QUEUE / HORIZON
│   │   └── horizon.conf
│   │
│   ├── reverb/                      ← WEBSOCKET / REVERB
│   │   └── reverb.conf
│   │
│   └── scripts/                     ← OPERATIONS
│       ├── entrypoint.sh
│       ├── healthcheck.sh
│       ├── deploy.sh
│       └── wait-for-services.sh
│
├── Dockerfile                       ← PRODUCTION APP IMAGE
├── Dockerfile.dev                   ← DEVELOPMENT APP IMAGE (optional)
│
├── compose.yaml                     ← DEVELOPMENT
├── compose.production.yaml          ← PRODUCTION
│
├── .dockerignore
├── .env.example
├── .env.production.example
│
├── composer.json
├── composer.lock
├── package.json
├── package-lock.json
├── vite.config.ts
└── README.md
```

---

## 4. Docker File Responsibilities

### `Dockerfile`

Builds the Laravel production image.

Typical responsibilities:

```text
PHP runtime
PHP extensions
Composer dependencies
Laravel application code
production configuration
compiled frontend assets
```

For production, use an optimized Composer installation such as:

```bash
composer install --no-dev --optimize-autoloader
```

and build frontend assets with:

```bash
npm ci
npm run build
```

---

### `compose.yaml`

Defines the development environment.

Typical development services:

```text
app
mysql
phpmyadmin
vite
queue
scheduler
redis
```

Development can use source-code bind mounts and Vite hot reload.

---

### `compose.production.yaml`

Defines the production runtime.

Typical production services:

```text
edge-nginx
nginx
app
mysql or managed MySQL
redis
horizon / queue
scheduler
reverb
```

Production should not expose phpMyAdmin publicly.

Production also should not run:

```bash
npm run dev
php artisan serve
```

---

### `docker/edge-nginx/default.conf`

Public-facing gateway configuration.

Responsibilities:

```text
HTTP → HTTPS
TLS / SSL
domain routing
reverse proxy
load balancing
access control
security headers
rate limiting
proxy headers
backup backend
```

This corresponds closely to the reverse-proxy role currently handled by the Laragon Nginx configuration.

---

### `docker/nginx/default.conf`

Laravel application web-server configuration.

Responsibilities:

```text
serve /var/www/html/public
Laravel front-controller routing
serve static assets
forward PHP requests to PHP-FPM
deny sensitive files
security-related Nginx rules
```

For the current combined Nginx + PHP-FPM container architecture:

```nginx
fastcgi_pass 127.0.0.1:9000;
```

If Nginx and PHP-FPM are separate containers, this would instead point to the PHP service, for example:

```nginx
fastcgi_pass app:9000;
```

---

### `docker/php/php.ini`

Project PHP runtime configuration.

Typical settings include:

```text
memory_limit
upload_max_filesize
post_max_size
max_execution_time
date.timezone
```

---

### `docker/php/www.conf`

PHP-FPM pool configuration.

Controls PHP-FPM process behavior, workers, user/group, and related pool settings.

Request flow:

```text
Nginx
   ↓
PHP-FPM
   ↓
Laravel
```

---

### `docker/mysql/my.cnf`

Custom MySQL server configuration.

This is mounted into the MySQL container and controls MySQL-specific server behavior.

---

### `docker/redis/redis.conf`

Optional Redis configuration.

Redis can support:

```text
cache
sessions
locks
queues
```

---

### `docker/horizon/horizon.conf`

Used when Horizon is selected for queue management.

Conceptually:

```text
Redis
   ↓
Horizon
   ↓
Laravel jobs
```

---

### `docker/reverb/reverb.conf`

Used when Laravel Reverb is part of the application.

Conceptually:

```text
Laravel
   ↓
Reverb
   ↓
Browser WebSocket connections
```

---

### `docker/scripts/entrypoint.sh`

Container startup logic.

For production, this script should be conservative and safe.

It should NOT automatically execute destructive commands such as:

```bash
php artisan migrate:fresh
```

Production deployments should use controlled migration steps such as:

```bash
php artisan migrate --force
```

---

### `docker/scripts/healthcheck.sh`

Checks whether the application/service is healthy.

Possible checks include:

```text
HTTP response
PHP-FPM availability
database connectivity
Redis connectivity
```

---

### `docker/scripts/deploy.sh`

Optional deployment helper.

Typical deployment tasks:

```text
pull/build image
run migrations
run Laravel optimization
restart/reload workers
verify health
```

---

### `docker/scripts/wait-for-services.sh`

Optional helper to wait for dependencies such as:

```text
MySQL
Redis
other internal services
```

before application processes start.

---

### `.dockerignore`

Prevents unnecessary or sensitive files from being sent into the Docker build context.

Typical exclusions:

```text
.git
.github
.env
node_modules
vendor
storage/logs
temporary/cache files
local development artifacts
```

---

## 5. Production Services and Their Duties

```text
edge-nginx
    ↓
External traffic / HTTPS / reverse proxy / load balancer


nginx
    ↓
Laravel public files and PHP request routing


app
    ↓
PHP-FPM + Laravel application


mysql
    ↓
Persistent application database


redis
    ↓
Cache + locks + queue backend + optional sessions


horizon
    ↓
Background queue workers


scheduler
    ↓
php artisan schedule:work


reverb
    ↓
WebSocket / realtime communication
```

---

## 6. Production Request Flow

```text
Browser
   │
   ▼
https://dolebelison.com
   │
   ▼
EDGE NGINX
   │
   ├── TLS
   ├── security
   ├── rate limiting
   ├── access control
   └── reverse proxy
   │
   ▼
APP NGINX
   │
   ▼
PHP-FPM
   │
   ▼
LARAVEL
   │
   ├───────────────┐
   ▼               ▼
 MySQL            Redis
```

---

## 7. Queue Flow

```text
Laravel
   │
   ▼
Redis
   │
   ▼
Horizon / Queue Worker
   │
   ▼
Background Job
```

This replaces the need to manually keep a terminal running:

```bash
php artisan queue:work
```

---

## 8. Scheduler Flow

```text
Scheduler container
       │
       ▼
php artisan schedule:work
       │
       ▼
Laravel Scheduler
       │
       ▼
Scheduled Commands / Jobs
```

This replaces manually keeping:

```bash
php artisan schedule:work
```

running in a terminal.

---

## 9. Reverb Flow

If Reverb is used:

```text
Browser
   │
   │ WebSocket
   ▼
Reverb
   ▲
   │
Laravel
```

---

## 10. Vite Production Flow

Vite should be a build-time concern in production.

```text
Docker Build
    │
    ▼
Node/Vite
    │
    ├── npm ci
    └── npm run build
            │
            ▼
       public/build
            │
            ▼
          Nginx
```

There should normally be no production equivalent of:

```bash
npm run dev
```

running continuously.

---

## 11. Database Flow

Inside Docker:

```text
Laravel
   │
   │ DB_HOST=mysql
   │ DB_PORT=3306
   ▼
MySQL container
   │
   ▼
Persistent Docker volume
```

The host port is separate from the Docker internal port.

For example:

```text
Windows host: 3307
Docker MySQL: 3306
```

Another project could use:

```text
Windows host: 3308
Docker MySQL: 3306
```

because each project can have its own isolated Docker network/container.

---

## 12. Development vs Production

### Development

```text
compose.yaml

app
mysql
phpmyadmin
vite
queue
scheduler
redis
```

Typical access:

```text
Laravel      → http://localhost:8000
Vite         → http://localhost:5173
MySQL host   → localhost:3307
phpMyAdmin   → http://localhost:8082
```

The exact host ports may be changed if they conflict with other applications.

### Production

```text
compose.production.yaml

edge-nginx
nginx
app
mysql / managed MySQL
redis
horizon
scheduler
reverb
```

Avoid:

```text
public phpMyAdmin
npm run dev
php artisan serve
migrate:fresh on startup
```

---

## 13. Production Deployment Flow

```text
DEVELOPER
    │
    ▼
Git push
    │
    ▼
CI/CD
    │
    ├── composer install --no-dev
    ├── npm ci
    ├── npm run build
    └── docker build
            │
            ▼
      Docker Registry
            │
            ▼
     Production Server
            │
            ▼
   Pull new application image
            │
            ▼
      Start/update services
            │
            ▼
 php artisan migrate --force
            │
            ▼
     php artisan optimize
            │
            ▼
     Restart/reload workers
            │
            ▼
        Health checks
            │
            ▼
        LIVE SYSTEM
```

---

## 14. Production Safety Principles

```text
1. Do not bake secrets into the Docker image.
2. Do not commit production .env files.
3. Do not expose phpMyAdmin publicly.
4. Do not run migrate:fresh automatically in production.
5. Build Vite assets during image creation/deployment.
6. Use --no-dev for production Composer dependencies.
7. Keep queue workers independently restartable.
8. Keep scheduled tasks independently restartable.
9. Keep application/database/network boundaries clear.
10. Use persistent storage and tested backups for important data.
```

---

## 15. Multi-Project Architecture on One Machine

```text
Docker Desktop
│
├── Project A
│   ├── Laravel 13
│   ├── PHP 8.4
│   ├── MySQL 8.0
│   └── Redis
│
├── Project B
│   ├── Laravel 10
│   ├── PHP 8.1
│   ├── MySQL 5.7
│   └── Redis
│
└── Project C
    ├── Laravel 12
    ├── PHP 8.3
    ├── MySQL 8.4
    └── Redis
```

Each application can have isolated:

```text
PHP version
PHP extensions
MySQL server
database
Redis
Node/Vite environment
Docker network
```

Only host-facing ports need to be unique when exposed to Windows.

---

## 16. Final Production Architecture

```text
                              INTERNET
                                  │
                                  ▼
                         ┌─────────────────┐
                         │   EDGE NGINX    │
                         │                 │
                         │ HTTPS / TLS     │
                         │ Reverse Proxy   │
                         │ Load Balancer   │
                         │ Security        │
                         └────────┬────────┘
                                  │
                                  ▼
                         ┌─────────────────┐
                         │  DOCKER NETWORK │
                         └────────┬────────┘
                                  │
        ┌───────────────┬─────────┼──────────┬───────────────┐
        │               │         │          │               │
        ▼               ▼         ▼          ▼               ▼
     NGINX             APP      REDIS      MYSQL           REVERB
        │               │         │          │               │
        └──────────────►│         │          │               │
                        │         │          │               │
                        ▼         ▼          ▼               │
                     LARAVEL   CACHE      DATABASE            │
                        │                                  WebSocket
              ┌─────────┼──────────┐                         ▲
              │         │          │                         │
              ▼         ▼          ▼                         │
          HORIZON   SCHEDULER   STORAGE                      │
              │         │                                    │
              ▼         ▼                                    │
            JOBS    CRON/TASKS ──────────────────────────────┘


                 BUILD PIPELINE
                      │
                  Node/Vite
                      │
                 npm run build
                      │
                      ▼
                public/build
                      │
                      ▼
                    NGINX
```

---

## 17. Final Production Service List

```text
edge-nginx
    → Public gateway, TLS, reverse proxy, load balancing

nginx
    → Laravel web server

app
    → PHP-FPM + Laravel

mysql
    → Persistent relational database

redis
    → Cache, locks, queue backend, optional sessions

horizon
    → Background jobs

scheduler
    → Laravel scheduled tasks

reverb
    → WebSockets / realtime events
```

Vite/Node is used during the build:

```text
Node/Vite
    → npm ci
    → npm run build
    → public/build
```

and is not normally a permanent production runtime service.

---

## 18. Important Architecture Note

When Edge Nginx serves multiple applications or servers, it is often best kept outside the individual application's Docker Compose stack.

Example:

```text
                    EDGE NGINX
                   /     |                        /      |                        ▼       ▼        ▼
          Laravel A  Laravel B  Laravel C
             Docker     Docker     Docker
```

Each application can then have its own:

```text
PHP version
MySQL version
Redis
Laravel version
Docker network
application containers
```

while the central Edge Nginx remains the public gateway.


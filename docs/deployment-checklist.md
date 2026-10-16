# Production Deployment Checklist

This document provides a preflight and production readiness verification protocol for deploying **Hardened WP** into staging and production environments.

---

## 1. Preflight Architecture & Secrets Verification

- [ ] **Mandatory Environment Secrets**:
  - `MARIADB_ROOT_PASSWORD` is generated with high entropy ($\ge$ 32 alphanumeric and special characters).
  - `MARIADB_PASSWORD` differs from root password and utilizes high entropy.
  - `DATABASE_URL` matches credentials: `mysql://wordpress_user:<STRONG_PASSWORD>@mariadb:3306/wordpress`.
  - All 8 WordPress salts (`AUTH_KEY`, `SECURE_AUTH_KEY`, `LOGGED_IN_KEY`, `NONCE_KEY`, `AUTH_SALT`, `SECURE_AUTH_SALT`, `LOGGED_IN_SALT`, `NONCE_SALT`) are generated via [Roots Salt Generator](https://roots.io/salts.html) or `wp secret-key`.
- [ ] **Filesystem Permissions for Secret Files**:
  - `.env` file permissions on host are restricted:
    ```bash
    chmod 600 .env
    chown $(id -u):$(id -g) .env
    ```
- [ ] **Web Server Configuration (`Caddyfile`)**:
  - `Caddyfile` is initialized from template (`cp Caddyfile.example Caddyfile`).
  - Active `Caddyfile` is excluded from version control (`.gitignore`).
  - Upload directory PHP execution block (`@blocked`) and security headers are verified.
- [ ] **Localhost Binding Enforced**:
  - `ports:` block in `docker-compose.yml` binds strictly to `127.0.0.1:${APP_PORT:-8080}:8080` (or uses an internal Docker bridge network without exposing host ports directly when fronted by an ingress proxy).

---

## 2. Supply Chain & Code Quality Gate

- [ ] **Linter Verification**:
  - All checks pass cleanly:
    ```bash
    make lint
    ```
- [ ] **Dependency Security Audit**:
  - No active CVE advisories in Composer dependencies:
    ```bash
    make audit
    ```
- [ ] **Immutable Base Image Digests**:
  - `Dockerfile` utilizes immutable `@sha256:...` digests for all stages (`composer:2.8`, `dunglas/frankenphp`, `wordpress:cli`).
- [ ] **Compose File Validation**:
  - Syntax validated with Docker Compose engine:
    ```bash
    docker compose config --quiet
    ```

---

## 3. Host Hardening & Container Confinement (cgroups)

- [ ] **Linux Capabilities & Privilege Escalation**:
  - `security_opt: ["no-new-privileges:true"]` is active on all services.
  - App executes under non-root UID/GID `82:82` (`USER 82:82`).
- [ ] **cgroups Resource Limits**:
  - `app` container constrained:
    - CPU: max 1.5 cores
    - Memory: 512 MB
    - PIDs limit: 100
  - `mariadb` container constrained:
    - CPU: max 1.5 cores
    - Memory: 1024 MB
    - PIDs limit: 150
- [ ] **Persistent Storage & Volume Mounts**:
  - Database stored in dedicated named volume `db_data`.
  - User media uploads stored in named volume `wp_uploads` (`/app/web/app/uploads`).
  - Permissions inside volumes owned by UID `82:82`.

---

## 4. Reverse Proxy & Ingress TLS Termination

- [ ] **Edge Ingress Proxy Configured**:
  - A production reverse proxy (such as [Caddy WAF](https://github.com/developmi/caddy-waf) or Nginx) fronts the container on port 80/443.
  - TLS 1.3 enforced with automated ACME certificate issuance.
  - HTTP Strict Transport Security (`HSTS`) header configured with `max-age=63072000; includeSubDomains; preload`.
- [ ] **Perimeter Defense-in-Depth**:
  - Direct execution of PHP scripts in uploads directory rejected with HTTP 403 (enforced natively in FrankenPHP Caddyfile `@disallowUploadPhp`).
  - Sensitive files (`.env`, `.git`, `composer.json`, `composer.lock`) blocked at ingress.
  - Ingress forwards real client IP via `X-Forwarded-For` and `X-Forwarded-Proto`.

---

## 5. Automated Backup & Retention Scheduling

- [ ] **Automated Cron Job Configured**:
  - Nightly backup task registered on host crontab:
    ```bash
    # Run automated backup daily at 03:00 UTC
    0 3 * * * cd /path/to/hardened-wp && make backup >> /var/log/hardened-wp-backup.log 2>&1
    ```
- [ ] **Retention Policy Active**:
  - Automatic pruning of backup archives older than 14 days verified.
  - SHA-256 manifests generated alongside archives.
- [ ] **Offsite Replication**:
  - Secondary replication of `./backups` to immutable offsite object storage (AWS S3, Cloudflare R2, or Backblaze B2) with Object Lock enabled.

---

## 6. Deployment Rollout Protocol

```bash
# 1. Pull latest production image or build
make build

# 2. Start stack in detached mode
make dev

# 3. Verify health probe
make test

# 4. Check container status
make ps

# 5. Execute database migration check (if applicable)
make wp CMD="core update-db"

# 6. Verify security header response
curl -I http://127.0.0.1:8080/healthz
```

---

## 7. Rollback Strategy

If deployment fails post-flight verification:
1. Revert container image tag to previous stable digest.
2. If database schema was modified, execute restoration following [`docs/runbooks/disaster-recovery.md`](./runbooks/disaster-recovery.md).
3. Notify the engineering team and review incident response steps in [`docs/runbooks/incident-response.md`](./runbooks/incident-response.md).

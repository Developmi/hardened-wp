<div align="center">

<img src="docs/assets/logo.png" width="180" alt="Hardened WP Logo Made By Developmi" />

# Hardened WP - WordPress, Production Ready | Developmi

*Hardened, enterprise-grade WordPress distribution built on Roots Bedrock and FrankenPHP in a secure container runtime.*

[![PHP 8.3](https://img.shields.io/badge/PHP_8.3-777BB4?style=for-the-badge&logo=php&logoColor=white)](https://www.php.net/)
[![FrankenPHP](https://img.shields.io/badge/FrankenPHP-FFD93C?style=for-the-badge&logo=caddy&logoColor=black)](https://frankenphp.dev/)
[![Bedrock Roots](https://img.shields.io/badge/Bedrock-Roots.io-525DDC?style=for-the-badge)](https://roots.io/bedrock/)
[![Docker](https://img.shields.io/badge/Docker-READY-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![CI](https://img.shields.io/badge/CI-Passing-brightgreen?style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/Developmi/hardened-wp/actions)
[![Supply Chain](https://img.shields.io/badge/Supply_Chain-Cosign_|_CycloneDX-4A90D9?style=for-the-badge)](https://github.com/Developmi/hardened-wp/actions)
[![Status](https://img.shields.io/badge/Status-Production_Active-brightgreen?style=for-the-badge)](https://github.com/Developmi/hardened-wp)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](./LICENSE.md)
![Maintainer](https://img.shields.io/badge/Maintainer-Miguel_Lozano_|_Cloud_&_Infrastructure_Engineer-black?style=for-the-badge)

> Curated by [Miguel Lozano](https://developmi.com) • [GitHub](https://github.com/Miguel-DevOps) • [Container Repository](https://github.com/Developmi/hardened-wp)

</div>

---

## 📋 Table of Contents

- [Hardened WP - WordPress, Production Ready | Developmi](#hardened-wp---wordpress-production-ready--developmi)
  - [📋 Table of Contents](#-table-of-contents)
  - [🎯 Overview](#-overview)
  - [🏗️ Architecture](#️-architecture)
  - [🔒 Security Hardening Posture](#-security-hardening-posture)
  - [⚡ Quick Start](#-quick-start)
    - [Prerequisites](#prerequisites)
    - [1. Clone \& Diagnose](#1-clone--diagnose)
    - [2. Configure Environment](#2-configure-environment)
    - [3. Launch Development Stack](#3-launch-development-stack)
    - [4. Verify Health Probe](#4-verify-health-probe)
    - [5. Access Application](#5-access-application)
  - [🛠️ Canonical Developer Workflows](#️-canonical-developer-workflows)
  - [🧩 WP-CLI Operations](#-wp-cli-operations)
  - [💾 Backup \& Disaster Recovery](#-backup--disaster-recovery)
  - [📚 SRE Documentation \& Runbooks](#-sre-documentation--runbooks)
  - [⚙️ Environment Configuration](#️-environment-configuration)
  - [🤝 Contributing](#-contributing)
  - [📄 License \& Support](#-license--support)

---

## 🎯 Overview

**Hardened WP** is an enterprise-grade containerized distribution of [Bedrock](https://roots.io/bedrock/) (the modern, twelve-factor WordPress boilerplate by Roots.io) served by [FrankenPHP](https://frankenphp.dev) (Go + PHP 8.3 with built-in Caddy server).

Unlike conventional WordPress Docker setups that expose writeable document roots, embed credentials in code, and run under unconfined root users, Hardened WP enforces strict security defaults:
- **Clean Separation of Concerns**: WordPress core is isolated in `/app/web/wp/` managed entirely by Composer, keeping VCS repositories clean.
- **Acorn Integration**: Roots Acorn provides Laravel 11 components, Blade templating, and service container architecture out of the box.
- **FrankenPHP Performance**: High-concurrency Caddy web server with native worker threads, HTTP/3, and zstd/brotli/gzip compression.
- **Zero Known Vulnerabilities**: Zero active CVEs across all transitive Composer dependencies.

---

## 🏗️ Architecture

```mermaid
flowchart TD
    Client["Client / Browser"] -->|"HTTPS / TLS 1.3"| Ingress["Ingress / Reverse Proxy<br/>(Caddy WAF / Edge TLS)"]
    Ingress -->|"HTTP (127.0.0.1:8080)"| FrankenPHP["FrankenPHP Container (UID 82:82)<br/>Caddy Web Server & Worker Engine"]

    subgraph AppContainer ["Docker Container: bedrock_app (UID 82:82)"]
        FrankenPHP -->|"/healthz"| Healthz["Health Probe (HTTP 200 OK)"]
        FrankenPHP -->|"Static Web Assets"| Static["Web Root (/app/web)"]
        FrankenPHP -->|"PHP FastCGI Engine"| Bedrock["WordPress Core + Roots Bedrock (/app)"]
        Bedrock -->|"Media Uploads"| UploadsVol["Named Volume: wp_uploads (/app/web/app/uploads)"]
        Bedrock -->|"Compiled Views"| CacheVol["Acorn Blade Cache (/app/web/app/cache)"]
    end

    subgraph DBContainer ["Docker Container: bedrock_db (MariaDB 11.4)"]
        Bedrock -->|"TCP / Port 3306"| MariaDB["MariaDB 11.4 Engine"]
        MariaDB -->|"Persistent Data"| DBVol["Named Volume: db_data (/var/lib/mysql)"]
    end

    subgraph BackupSvc ["Automated Operations Service"]
        BackupScript["Backup Utility (scripts/3-backup.sh)"] -->|"mariadb-dump"| MariaDB
        BackupScript -->|"tar archive"| UploadsVol
        BackupScript -->|"SHA-256 Manifest + 14d Retention"| BackupsDir["Cold Backups (./backups)"]
    end
```

---

## 🔒 Security Hardening Posture

Bedrock Ship incorporates multi-tier defense-in-depth controls across supply chain, container runtime, network perimeter, and filesystem:

| Security Vector | Implementation Detail | Operational Benefit |
| :--- | :--- | :--- |
| **Runtime Identity** | Non-root numeric execution (`USER 82:82`, `www-data:www-data`) | Compliance with Kubernetes Restricted Pod Security Standards. |
| **Privilege Escalation** | `security_opt: ["no-new-privileges:true"]` on all containers | Prevents `setuid` privilege escalation exploits inside containers. |
| **cgroups Resource Limits** | Explicit CPU (1.5), Memory (512MB/1024MB), and PIDs limits (100/150) | Eliminates noisy-neighbor risks and mitigates Fork Bomb DoS. |
| **Vulnerability Status** | **0 CVEs** verified by `composer audit` and continuous Trivy scanning | Remediated all transitive Symfony and Guzzle vulnerability vectors. |
| **Uploads Execution Lock** | Caddy matcher `@disallowUploadPhp` returning `403 Forbidden` | Completely prevents execution of uploaded webshells in `/app/uploads/`. |
| **Localhost Port Confinement** | Bound strictly to `127.0.0.1:${APP_PORT:-8080}:8080` in Compose | Prevents unintended public exposure on multi-tenant Docker hosts. |
| **Base Image Immutability** | Multi-stage stages digest-pinned to immutable `@sha256:...` digests | Guarantees deterministic, tamper-proof reproducible container builds. |
| **Supply Chain Assurance** | Keyless Cosign OIDC signing and CycloneDX SBOM generation | Verifiable origin, non-repudiation, and transparent dependency audit. |
| **Liveness Probing** | Dedicated `/healthz` endpoint returning `200 OK` | Zero-overhead uptime checks without hitting PHP worker processes. |

---

## ⚡ Quick Start

### Prerequisites
- Docker Engine 24.0+ and Docker Compose v2.20+
- GNU Make

### 1. Clone & Diagnose
```bash
git clone https://github.com/Developmi/hardened-wp.git
cd hardened-wp
make doctor
```

### 2. Configure Environment & Web Server
```bash
cp .env.example .env
cp Caddyfile.example Caddyfile
# Configure MARIADB_ROOT_PASSWORD, DATABASE_URL, and cryptographic salts in .env
```

### 3. Launch Development Stack
```bash
make dev
```

### 4. Verify Health Probe
```bash
make test
```

### 5. Access Application
Open [http://127.0.0.1:8080](http://127.0.0.1:8080) in your browser to complete WordPress initial setup.

---

## 🛠️ Canonical Developer Workflows

Hardened WP provides a standardized, canonical `Makefile` interface for development, quality control, operations, and testing:

```bash
make help
```

| Category | Command | Action |
| :--- | :--- | :--- |
| **Setup** | `make doctor` | Verify prerequisites (`docker`, `compose`, `git`, `.env`) |
| | `make build` | Build local container image (`developmi/hardened-wp:local`) |
| **Runtime & Stack** | `make dev` | Launch complete stack in background (`docker compose up -d`) |
| | `make down` | Stop running containers (`docker compose down`) |
| | `make down-v` | Stop containers and wipe volumes (`docker compose down -v`) |
| | `make restart` | Restart stack services (`docker compose restart`) |
| | `make ps` | Display active container status and health (`docker compose ps`) |
| | `make logs` | Follow aggregate logs from all services (`docker compose logs -f`) |
| | `make logs-app` | Follow application container logs (`docker compose logs -f app`) |
| | `make logs-db` | Follow database container logs (`docker compose logs -f mariadb`) |
| **Quality & Linting** | `make lint` | Run entire linter suite (PHP, Composer, shell, actions, Dockerfile, zizmor) |
| | `make lint-php` | Validate PHP code style with Laravel Pint (`pint --test`) |
| | `make lint-composer` | Validate `composer.json` and `composer.lock` in strict mode |
| | `make lint-shell` | Lint shell scripts with ShellCheck |
| | `make lint-actions` | Lint GitHub Actions workflows with Actionlint |
| | `make lint-docker` | Lint Dockerfile with Hadolint |
| | `make lint-security` | Lint GitHub Actions workflows with Zizmor (`zizmor .`) |
| | `make format` | Automatically reformat PHP codebase with Laravel Pint |
| | `make audit` | Audit Composer dependencies for known CVEs (`composer audit`) |
| | `make test` | Probe application liveness endpoint (`/healthz`) |
| | `make test-security` | Scan local image for CRITICAL and HIGH CVEs with Trivy |
| **Utilities** | `make cli` | Open interactive shell inside application container |
| | `make wp CMD="..."` | Execute WP-CLI command (e.g. `make wp CMD="core version"`) |
| | `make backup` | Execute database + uploads backup with SHA-256 manifest |

---

## 🧩 WP-CLI Operations

Manage WordPress core, plugins, themes, and database operations through the unified `make wp` target:

```bash
# Check WordPress version
make wp CMD="core version"

# List installed plugins
make wp CMD="plugin list"

# Install and activate a plugin
make wp CMD="plugin install classic-editor --activate"

# Flush object cache
make wp CMD="cache flush"

# Check database tables
make wp CMD="db check"
```

---

## 💾 Backup & Disaster Recovery

Bedrock Ship includes an automated backup utility (`scripts/3-backup.sh` / `make backup`) that executes non-blocking database exports and compresses media uploads:

```bash
make backup
```

Outputs generated in `./backups/`:
- `db_YYYY-MM-DD_HH-MM-SS.sql.gz` - Compressed single-transaction MariaDB dump.
- `uploads_YYYY-MM-DD_HH-MM-SS.tar.gz` - Compressed media uploads archive.
- `backup_YYYY-MM-DD_HH-MM-SS.sha256` - Cryptographic SHA-256 verification manifest.
- **Automatic Pruning**: Archives older than 14 days are automatically pruned.

For complete restoration procedures, see [Disaster Recovery Runbook](docs/runbooks/disaster-recovery.md).

---

## 📚 SRE Documentation & Runbooks

Operational, production, and triage runbooks are maintained under [`docs/`](docs/):

- 🚨 [Incident Response Runbook](docs/runbooks/incident-response.md) - Step-by-step triage guide for container crashloops, MariaDB socket exhaustion, backup failures, and PHP error surges.
- 🔄 [Disaster Recovery Runbook](docs/runbooks/disaster-recovery.md) - Step-by-step restoration procedure for database and media archives with SHA-256 integrity validation.
- ✅ [Production Deployment Checklist](docs/deployment-checklist.md) - Preflight and production readiness verification covering secrets, TLS termination, cgroups, and backup schedules.

---

## ⚙️ Environment Configuration

| Variable | Required | Default | Description |
| :--- | :---: | :--- | :--- |
| `DATABASE_URL` | **Yes** | - | `mysql://user:pass@mariadb:3306/dbname` |
| `MARIADB_ROOT_PASSWORD`| **Yes** | - | Strong MariaDB root password |
| `MARIADB_PASSWORD` | **Yes** | - | Strong password for WordPress database user |
| `MARIADB_DATABASE` | No | `wordpress` | Database schema name |
| `MARIADB_USER` | No | `wordpress_user` | Application database user |
| `WP_ENV` | No | `production` | Environment tier (`development`, `staging`, `production`) |
| `WP_HOME` | No | `http://localhost:8080` | Canonical site URL |
| `WP_SITEURL` | No | `${WP_HOME}/wp` | WordPress core URL |
| `AUTH_KEY` to `NONCE_SALT` | **Yes** | - | 8 unique cryptographic salts ([Roots Salt Generator](https://roots.io/salts.html)) |
| `APP_PORT` | No | `8080` | Host port bound to loopback `127.0.0.1` |

---

## 🤝 Contributing

Contributions are welcome! Please review [CONTRIBUTING.md](./CONTRIBUTING.md) and our [Security Policy](./SECURITY.md).

- Commits must adhere to [Conventional Commits](https://www.conventionalcommits.org/).
- Do not include `Co-Authored-By` or AI attribution trailers.
- All submissions must pass `make lint` and `make audit`.

---

## 📄 License & Support

Copyright © 2026 Miguel Lozano | Developmi. All rights reserved.

Licensed under the [MIT License](./LICENSE.md).

**Maintained by:** Miguel Lozano | Developmi
- **Role:** Cloud & Infrastructure Engineer | FinOps & Bare Metal Specialist | AI Sovereignty Strategist under NIST/DORA Standards
- **Philosophy:** *Security is not a feature; it is the baseline.*
- **Website:** [developmi.com](https://developmi.com)
- **GitHub:** [Miguel-DevOps](https://github.com/Miguel-DevOps)
- **LinkedIn:** [Miguel Lozano](https://www.linkedin.com/in/miguel-dev-ops)

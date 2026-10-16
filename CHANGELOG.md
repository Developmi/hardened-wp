# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2026-10-15

### Added

- **Named Persistent Volume (`wp_uploads`)**: Dedicated Docker named volume for `/app/web/app/uploads` ensuring media persistence across container recreations and zero data loss during zero-downtime rollouts.
- **Caddy Security Headers**: Enforced defense-in-depth HTTP headers in FrankenPHP Caddyfile (`X-Content-Type-Options: nosniff`, `X-Frame-Options: SAMEORIGIN`, `Referrer-Policy: strict-origin-when-cross-origin`).
- **Dedicated Health Endpoint (`/healthz`)**: Lightweight native Caddy `/healthz` probe returning `200 OK` without triggering PHP worker overhead, utilized by Docker container healthcheck and load balancer uptime probes.
- **SHA-256 Backup Manifests & Retention**: Automated backup utility (`scripts/3-backup.sh`) creating atomic database dumps (`.sql.gz`) and uploads archives (`.tar.gz`), generating cryptographic SHA-256 checksum manifests, and enforcing 14-day retention pruning.
- **Segregated CI/CD Pipeline**: Independent GitHub Actions workflows separating fast PR validation (`lint.yml`) from container build, Trivy vulnerability scanning, Cosign OIDC signing, and SBOM generation (`docker-build-scan-sign.yml`).
- **Supply Chain Signing & CycloneDX SBOM**: Keyless container image signing via Cosign and automated CycloneDX Software Bill of Materials (SBOM) generation on GHCR releases.
- **Multi-Linter Quality Suite**: Integrated Laravel Pint, Composer validation, ShellCheck, Actionlint, Hadolint, and Zizmor in CI and local developer workflows.
- **Canonical Makefile**: Standardized developer interface featuring ANSI category formatting, automated environment diagnostics (`make doctor`), and runtime, testing, linting, and backup workflows.
- **SRE Operational Runbooks**: Disaster recovery with checksum restoration (`docs/runbooks/disaster-recovery.md`), incident response protocol (`docs/runbooks/incident-response.md`), and production deployment checklist (`docs/deployment-checklist.md`).

### Changed

- **WordPress Upgrade (7.1.3)**: Upgraded core WordPress engine from 6.9.4 to 7.1.3 via `roots/wordpress`.
- **Roots Acorn Framework (6.3.0)**: Upgraded Roots Acorn Laravel framework bindings from 6.1.0 to 6.3.0.
- **Twenty Twenty-Five Theme (1.5)**: Upgraded default modern block theme to 1.5.
- **Laravel Pint (1.32.1)**: Upgraded code styling tools to latest stable release.
- **Digest-Pinned Base Images**: Pinned all multi-stage base images (`composer:2.8`, `dunglas/frankenphp:1-php8.3-alpine`, `wordpress:cli-php8.3`) to immutable SHA-256 digests, eliminating base image drift and supply-chain tampering.
- **Numeric Non-Root Execution (`82:82`)**: Enforced runtime execution as numeric UID/GID `82:82` (`www-data:www-data`), satisfying Kubernetes Restricted Pod Security Standards and rootless container engines.
- **Transitive Dependency CVE Remediation**: Updated all transitive `symfony/*` and `guzzlehttp/*` dependencies in `composer.lock`, eliminating all 21 known CVEs with 0 active Composer security advisories (`composer audit`).
- **Repository Branding & Ownership**: Migrated and standardized to `developmi/hardened-wp` under organization Developmi.

### Security

- **Localhost Loopback Port Binding**: Restricted default host port exposure in `docker-compose.yml` to `127.0.0.1:${APP_PORT:-8080}:8080`, preventing inadvertent public exposure of unauthenticated development endpoints.
- **Blocked PHP Execution in Uploads (`403 Forbidden`)**: Configured Caddy matcher `@disallowUploadPhp` denying direct execution of `.php` scripts located within `/app/uploads/` with HTTP 403, mitigating malicious media shell uploads.
- **Mandatory Environment Secret Validation**: Enforced strict variable interpolation checks for database credentials, root passwords, and WordPress authentication salts (`DATABASE_URL`, `MARIADB_ROOT_PASSWORD`, `AUTH_KEY`, `AUTH_SALT`, etc.), aborting startup on missing credentials.

## [1.0.0] - 2026-05-09

### Added

- **Roots Bedrock Architecture**: Modern WordPress 12-factor directory layout isolating core in `/web/wp/` with Composer dependency management.
- **FrankenPHP Runtime**: High-performance Caddy application server running PHP 8.3 with Alpine Linux base.
- **Rootless Container Execution**: Unprivileged container runtime environment under non-root Alpine user.
- **Acorn Integration**: Modern Laravel components, Blade templating engine, and service container bindings for WordPress.
- **Operational Automation Scripts**: Initial developer and operational workflows (`scripts/1-setup-dev.sh`, `scripts/2-build-prod.sh`, `scripts/3-backup.sh`).
- **Initial Repository Structure**: Workspace foundation established in personal repository (`miguel-devops/bedrock-ship`).

[Unreleased]: https://github.com/Developmi/hardened-wp/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/Developmi/hardened-wp/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/Developmi/hardened-wp/releases/tag/v1.0.0

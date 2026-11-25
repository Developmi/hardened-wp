# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.3] - 2026-11-24

### Added

- **OpenVEX Governance Document (`openvex.json`)**: Machine-readable VEX statements documenting `not_affected` exploitability justifications for unpatchable upstream Go runtime components (`CVE-2026-78661`, `CVE-2026-116587`).
- **Preflight Verification Gate (`make release-ready`)**: Deterministic Makefile umbrella target executing `lint`, `audit`, `build`, `test-security`, and integration tests in sequence.
- **FinOps Documentation**: Documented Bare Metal / VPS operational cost advantages and ~75–85% OpEx reduction metrics in README.
- **CI Dependency Vulnerability Gate**: Integrated automated `composer audit` step into CI `lint.yml` workflow.

### Changed

- **Container Hardening (`libxml2`)**: Upgraded `libxml2` to `2.13.9-r3` via `apk upgrade` in `Dockerfile`, eliminating `CVE-2026-86144`.
- **MariaDB 11.4 LTS Multi-Arch Pinning**: Pinned `mariadb:11.4` in `docker-compose.yml` to immutable multi-arch index digest `sha256:a8992b5e5404d11e03c54a31d0c1bdea3fd116d283aa6d1a627551f29045309b`.
- **CI/CD Workflow Hardening**:
  - Enforced baseline `permissions: contents: read` at top level in `docker-build-scan-sign.yml`.
  - Pinned all workflow runners to deterministic `ubuntu-24.04` LTS across `docker-build-scan-sign.yml`, `lint.yml`, and `test.yml`.
  - Configured `concurrency:` groups with `cancel-in-progress: true` in `lint.yml` and `test.yml` to prevent duplicate parallel CI runs.
- **Standard OCI Container Labels**: Updated image metadata in `Dockerfile` with standard OCI labels (`org.opencontainers.image.*`) and bumped version to `2.0.3`.
- **WordPress Core Engine (`roots/wordpress`)**: Upgraded `roots/wordpress` and `roots/wordpress-no-content` from 7.1.4 to `7.1.5` (consolidates PR #18).
- **Code Style Tooling (`laravel/pint`)**: Upgraded `laravel/pint` from v1.32.1 to `v1.32.3` (consolidates PR #19).
- **GitHub Actions Security Bumps**:
  - Pinned `docker/login-action` to `v4.8.0` (`8aa5831fb8d48d8f76594c7ddde61ae58019f550`, consolidates PR #16).
  - Pinned `sigstore/cosign-installer` to `v4.1.3` (`756fe2d284c7292c4e9b62c8a28f1e5629c59532`, consolidates PR #17).
  - Pinned `github/codeql-action/upload-sarif` to `0911ee96d2d6c8def97122c36c5cadd93829a4b4` (consolidates PR #14).
- **Ignore Standard Alignment**: Synchronized `.dockerignore` and `.gitignore` against master standards to exclude Python caches, task tracking, and cryptographic keys.
- **Trivy CI Alignment**: Pinned `aquasecurity/setup-trivy` to `v0.76.0` across CI workflows and wired `--vex openvex.json`.

## [2.0.2] - 2026-11-04

### Security

- **Transitive Symfony Security Patches**: Upgraded `symfony/*` components to `v7.4.23`, remediating `CVE-2026-118514`, `CVE-2026-118516`, and `CVE-2026-45070` with zero open advisories (`composer audit`).
- **Alpine System Patches (`curl`)**: Added `apk upgrade --no-cache curl libcurl` to production runtime image, resolving `CVE-2026-92392`.

### Changed

- **DevSecOps Tooling**: Updated `pyproject.toml` and `uv.lock` pinning `ruff==0.9.10` and `mypy==1.15.0`.

## [2.0.1] - 2026-10-22

### Changed

- **WordPress Core Engine (7.1.4)**: Upgraded `roots/wordpress` to 7.1.4.
- **CI/CD Action Bumps**: Updated `docker/login-action` to 4.7.0 and `astral-sh/setup-uv` to 10.3.3.

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

[Unreleased]: https://github.com/Developmi/hardened-wp/compare/v2.0.3...HEAD
[2.0.3]: https://github.com/Developmi/hardened-wp/compare/v2.0.2...v2.0.3
[2.0.2]: https://github.com/Developmi/hardened-wp/compare/v2.0.1...v2.0.2
[2.0.1]: https://github.com/Developmi/hardened-wp/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/Developmi/hardened-wp/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/Developmi/hardened-wp/releases/tag/v1.0.0

# Hardened WP (Developmi)

## Stack
- **Type**: Production-ready WordPress containerized distribution (Roots Bedrock + FrankenPHP + MariaDB)
- **Base image (runtime)**: `dunglas/frankenphp:1-php8.3-alpine` (digest-pinned to `@sha256:...`)
- **Base image (builder)**: `composer:2.8` (digest-pinned to `@sha256:...`)
- **PHP CLI image**: `wordpress:cli-php8.3` (digest-pinned to `@sha256:...`)
- **Web Server / Application Server**: FrankenPHP (Caddy v2 with native CGO PHP 8.3 worker/server mode)
- **Framework & Boilerplate**: Roots Bedrock (Twelve-Factor WordPress) + Roots Acorn 6.x (Laravel service container & Blade template layer)
- **Database**: MariaDB 11.4 LTS
- **Orchestration**: Docker Compose v2
- **Python / Dev Tooling**: `uv` with `pyproject.toml` (linting dependencies: `yamllint`, `zizmor`)

## Commands
- **Environment Doctor**: `make doctor`
- **Provision Standalone Tools**: `make tools` (cryptographic SHA-256 verified in `tools/bin`)
- **Force Reinstall Tools**: `make reinstall`
- **Build image**: `make build` (`developmi/hardened-wp:local`)
- **Development stack**: `make dev` (`docker compose up -d`)
- **Stop stack**: `make down` (`docker compose down`)
- **Wipe volumes & stop**: `make down-v` (`docker compose down -v`)
- **Logs**: `make logs` | `make logs-app` | `make logs-db`
- **Shell / WP-CLI**: `make cli` | `make wp CMD="core version"`
- **Lint all**: `make lint` (7 linters: Pint, Composer, ShellCheck, actionlint, hadolint, yamllint, zizmor)
- **Format PHP**: `make format` (Laravel Pint)
- **Dependency audit**: `make audit` (`composer audit`)
- **Security test suite**: `make test` (`scripts/4-test-security.sh`, intelligent lifecycle)
- **Trivy scan**: `make test-security` (standalone Trivy container scan)
- **Automated Backup**: `make backup` (`scripts/3-backup.sh`)

## Configuration & Architecture Rules
- **Decoupled Caddy Configuration**:
  - `Caddyfile.example` is committed as the canonical template.
  - `Caddyfile` is the active, gitignored file (`.gitignore`).
  - Always copy `Caddyfile.example` to `Caddyfile` when setting up a fresh clone (`cp Caddyfile.example Caddyfile`).
  - Dockerfile copies `Caddyfile*` and falls back cleanly to `Caddyfile.example` if local `Caddyfile` is absent.
- **PHP Runtime Configurations**:
  - Centralized in `config/php/`: `zz-opcache.ini`, `uploads.ini`, `error-logging.ini`.
  - Copied into container at build time: `COPY config/php/ /usr/local/etc/php/conf.d/`.
- **Media Uploads & Storage**:
  - Uploads live at `/app/web/app/uploads` and **MUST** be backed by the persistent Docker volume `wp_uploads`.
  - Never execute PHP scripts inside `/app/web/app/uploads/` (enforced by Caddy matcher `@blocked`).
- **Disaster Recovery**:
  - `scripts/3-backup.sh` dumps the MariaDB database via `mariadb-dump` and archives the `wp_uploads` volume data directly from the container layer, generating SHA-256 manifests with 14-day rotation.

## Security Posture
- **Identity**: Non-root execution (`USER 82:82`, `www-data:www-data`).
- **Privilege Escalation**: `no-new-privileges:true` active on all containers in Compose.
- **cgroups Limits**: App limited to 1.5 CPUs, 512MB RAM, 100 PIDs; MariaDB limited to 1.5 CPUs, 1024MB RAM, 150 PIDs.
- **Port Confinement**: Application binds strictly to `127.0.0.1:${APP_PORT:-8080}:8080`.
- **WordPress Security Constants**:
  - `DISALLOW_FILE_MODS=true`: Code execution / installation from WP admin dashboard is completely disabled.
  - Cryptographic salts: All 8 salts validated in `config/application.php`.
- **Supply Chain**:
  - All Dockerfile stages pinned with immutable SHA256 digests.
  - Multi-arch CI builds with Cosign keyless OIDC signing and CycloneDX SBOM generation.

## CI/CD Workflows
- **`docker-build-scan-sign.yml`**: Gated by Trivy CRITICAL/HIGH scan. Builds amd64/arm64 images, signs with Cosign, generates SBOM, and publishes to `ghcr.io/developmi/hardened-wp` on `v*` tags.
- **`lint.yml`**: Validates Composer, ShellCheck, actionlint, hadolint, and zizmor on every PR and push.
- **`test.yml`**: Boots ephemeral Compose stack, validates `/healthz`, executes security test suite and backup checksum integrity.

## Conventions
- **Commit Style**: Conventional Commits only (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, `ci:`). Never add AI attribution or "Co-Authored-By" tags.
- **Branch Naming**: `feat/description`, `fix/issue-description`, `docs/description`, `chore/description`.
- **AI & Workflow Artifacts**: All AI session logs, memory, and orchestration artifacts (`.engram/`, `openspec/`, `sdd/`, `odd/`, `rdd/`, `atl/`, `.agent/`, `.claude/`, `.gemini/`) are strictly excluded via `.gitignore`.

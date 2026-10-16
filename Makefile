include tools/versions.mk

TOOLS := tools/bin
UV    := uv run

.DEFAULT_GOAL := help

# ANSI colors for styling
BOLD   := \033[1m
CYAN   := \033[36m
GREEN  := \033[32m
YELLOW := \033[33m
BLUE   := \033[34m
RED    := \033[31m
RESET  := \033[0m

DOCKER_UID   := $(shell id -u):$(shell id -g)
COMPOSER_RUN := docker run --rm -u $(DOCKER_UID) -v $$(pwd):/app -w /app composer:$(COMPOSER_VERSION)@$(COMPOSER_DIGEST)

IMAGE_NAME   ?= developmi/hardened-wp
APP_PORT     ?= 8080

.PHONY: help
help:
	@printf "\n$(BOLD)Hardened WP (Developmi) - Developer Workflows$(RESET)\n"
	@printf "$(BOLD)=============================================$(RESET)\n\n"
	@printf "$(CYAN)$(BOLD)Setup & Environment$(RESET)\n"
	@printf "  $(GREEN)tools$(RESET)          Verify and provision development standalone binaries (tools/bin)\n"
	@printf "  $(GREEN)reinstall$(RESET)      Force reinstall development binaries\n"
	@printf "  $(GREEN)doctor$(RESET)         Verify development prerequisites, tools, and environment\n"
	@printf "  $(GREEN)build$(RESET)          Build local container image ($(IMAGE_NAME):local)\n"
	@printf "\n$(CYAN)$(BOLD)Runtime & Stack$(RESET)\n"
	@printf "  $(GREEN)dev$(RESET)            Start stack in background (docker compose up -d)\n"
	@printf "  $(GREEN)down$(RESET)           Stop stack containers\n"
	@printf "  $(GREEN)down-v$(RESET)         Stop stack and remove volumes (wipes DB & uploads)\n"
	@printf "  $(GREEN)restart$(RESET)        Restart stack containers\n"
	@printf "  $(GREEN)ps$(RESET)             List running stack containers\n"
	@printf "  $(GREEN)logs$(RESET)           Follow logs from all services\n"
	@printf "  $(GREEN)logs-app$(RESET)       Follow application container logs\n"
	@printf "  $(GREEN)logs-db$(RESET)        Follow MariaDB container logs\n"
	@printf "\n$(CYAN)$(BOLD)Quality & Testing$(RESET)\n"
	@printf "  $(GREEN)lint$(RESET)           Run all linters (Pint, Composer, ShellCheck, actionlint, hadolint, yamllint, zizmor)\n"
	@printf "  $(GREEN)lint-php$(RESET)       Check PHP code style with Laravel Pint\n"
	@printf "  $(GREEN)lint-composer$(RESET)  Validate composer.json and composer.lock in strict mode\n"
	@printf "  $(GREEN)lint-shell$(RESET)     Lint shell scripts with standalone shellcheck\n"
	@printf "  $(GREEN)lint-actions$(RESET)   Lint GitHub Actions workflows with standalone actionlint\n"
	@printf "  $(GREEN)lint-docker$(RESET)    Lint Dockerfile with standalone hadolint\n"
	@printf "  $(GREEN)lint-yaml$(RESET)      Lint YAML definitions with yamllint\n"
	@printf "  $(GREEN)lint-security$(RESET)  Audit GitHub Actions security with zizmor\n"
	@printf "  $(GREEN)format$(RESET)         Auto-format PHP codebase with Laravel Pint\n"
	@printf "  $(GREEN)audit$(RESET)          Audit Composer dependencies for known vulnerabilities\n"
	@printf "  $(GREEN)test$(RESET)           Run security test suite (intelligent ephemeral lifecycle)\n"
	@printf "  $(GREEN)test-security$(RESET)  Run standalone Trivy security scan against $(IMAGE_NAME):local\n"
	@printf "\n$(CYAN)$(BOLD)Utilities$(RESET)\n"
	@printf "  $(GREEN)cli$(RESET)            Open interactive shell inside application container as www-data\n"
	@printf "  $(GREEN)wp$(RESET)             Run WP-CLI command (e.g. make wp CMD=\"core version\")\n"
	@printf "  $(GREEN)backup$(RESET)         Run automated database and uploads backup with SHA-256 manifest\n"
	@printf "\n"

.PHONY: tools
tools:
	@ACTIONLINT_VERSION=$(ACTIONLINT_VERSION) \
	ACTIONLINT_SHA256_LINUX_AMD64=$(ACTIONLINT_SHA256_LINUX_AMD64) \
	ACTIONLINT_SHA256_LINUX_ARM64=$(ACTIONLINT_SHA256_LINUX_ARM64) \
	ACTIONLINT_SHA256_DARWIN_AMD64=$(ACTIONLINT_SHA256_DARWIN_AMD64) \
	ACTIONLINT_SHA256_DARWIN_ARM64=$(ACTIONLINT_SHA256_DARWIN_ARM64) \
	HADOLINT_VERSION=$(HADOLINT_VERSION) \
	HADOLINT_SHA256_LINUX_AMD64=$(HADOLINT_SHA256_LINUX_AMD64) \
	HADOLINT_SHA256_LINUX_ARM64=$(HADOLINT_SHA256_LINUX_ARM64) \
	HADOLINT_SHA256_DARWIN_AMD64=$(HADOLINT_SHA256_DARWIN_AMD64) \
	HADOLINT_SHA256_DARWIN_ARM64=$(HADOLINT_SHA256_DARWIN_ARM64) \
	SHELLCHECK_VERSION=$(SHELLCHECK_VERSION) \
	SHELLCHECK_SHA256_LINUX_AMD64=$(SHELLCHECK_SHA256_LINUX_AMD64) \
	SHELLCHECK_SHA256_LINUX_ARM64=$(SHELLCHECK_SHA256_LINUX_ARM64) \
	SHELLCHECK_SHA256_DARWIN_AMD64=$(SHELLCHECK_SHA256_DARWIN_AMD64) \
	SHELLCHECK_SHA256_DARWIN_ARM64=$(SHELLCHECK_SHA256_DARWIN_ARM64) \
	TRIVY_VERSION=$(TRIVY_VERSION) \
	TRIVY_SHA256_LINUX_AMD64=$(TRIVY_SHA256_LINUX_AMD64) \
	TRIVY_SHA256_LINUX_ARM64=$(TRIVY_SHA256_LINUX_ARM64) \
	TRIVY_SHA256_DARWIN_AMD64=$(TRIVY_SHA256_DARWIN_AMD64) \
	TRIVY_SHA256_DARWIN_ARM64=$(TRIVY_SHA256_DARWIN_ARM64) \
	./tools/install.sh

.PHONY: reinstall
reinstall:
	@REINSTALL=1 $(MAKE) tools

.PHONY: doctor
doctor: tools
	@printf "\n$(BOLD)Hardened WP Environment Doctor$(RESET)\n"
	@printf "$(BOLD)==============================$(RESET)\n"
	@if command -v docker >/dev/null 2>&1; then \
		printf "%-20s $(GREEN)✓ installed ($$(docker version --format '{{.Client.Version}}'))$(RESET)\n" "Docker"; \
	else \
		printf "%-20s $(RED)✗ not installed$(RESET)\n" "Docker"; \
	fi
	@if docker compose version >/dev/null 2>&1; then \
		printf "%-20s $(GREEN)✓ installed ($$(docker compose version --short))$(RESET)\n" "Docker Compose"; \
	else \
		printf "%-20s $(RED)✗ not installed$(RESET)\n" "Docker Compose"; \
	fi
	@if command -v git >/dev/null 2>&1; then \
		printf "%-20s $(GREEN)✓ installed ($$(git --version | awk '{print $$3}'))$(RESET)\n" "Git"; \
	else \
		printf "%-20s $(RED)✗ not installed$(RESET)\n" "Git"; \
	fi
	@if command -v uv >/dev/null 2>&1; then \
		printf "%-20s $(GREEN)✓ installed ($$(uv --version | awk '{print $$2}'))$(RESET)\n" "uv"; \
	else \
		printf "%-20s $(YELLOW)⚠ not installed$(RESET)\n" "uv"; \
	fi
	@if [ -f .env ]; then \
		printf "%-20s $(GREEN)✓ found$(RESET)\n" ".env file"; \
	else \
		printf "%-20s $(YELLOW)⚠ not found (copy .env.example to .env)$(RESET)\n" ".env file"; \
	fi
	@if [ -f Caddyfile ]; then \
		printf "%-20s $(GREEN)✓ found$(RESET)\n" "Caddyfile"; \
	else \
		printf "%-20s $(YELLOW)⚠ not found (copy Caddyfile.example to Caddyfile)$(RESET)\n" "Caddyfile"; \
	fi
	@printf "\n$(CYAN)$(BOLD)Verified Standalone Tooling$(RESET)\n"
	@printf "%-20s %s\n" "actionlint" "$$($(TOOLS)/actionlint -version 2>/dev/null | head -1)"
	@printf "%-20s %s\n" "hadolint" "$$($(TOOLS)/hadolint --version 2>/dev/null | awk '{print $$NF}')"
	@printf "%-20s %s\n" "shellcheck" "$$($(TOOLS)/shellcheck --version 2>/dev/null | grep version: | awk '{print $$2}')"
	@printf "%-20s %s\n" "trivy" "$$($(TOOLS)/trivy --version 2>/dev/null | head -1 | awk '{print $$2}')"
	@printf "%-20s %s\n" "yamllint" "$$($(UV) yamllint --version 2>/dev/null | awk '{print $$2}')"
	@printf "%-20s %s\n" "zizmor" "$$($(UV) zizmor --version 2>/dev/null | awk '{print $$2}')"
	@printf "\n"

.PHONY: build
build:
	@if [ ! -f Caddyfile ]; then cp Caddyfile.example Caddyfile; fi
	docker build --pull -t $(IMAGE_NAME):local .

.PHONY: dev
dev:
	docker compose up -d

.PHONY: down
down:
	@printf "$(BLUE)Stopping stack containers...$(RESET)\n"
	@docker compose down
	@printf "$(GREEN)✓ Stack stopped.$(RESET)\n"

.PHONY: down-v
down-v:
	@printf "\n$(RED)$(BOLD)⚠️ WARNING: Destroying containers and WIPING persistent volumes (db_data and wp_uploads)...$(RESET)\n"
	@docker compose down -v
	@printf "$(GREEN)✓ Stack stopped and all data volumes removed.$(RESET)\n\n"

.PHONY: restart
restart:
	docker compose restart

.PHONY: logs
logs:
	docker compose logs -f

.PHONY: logs-app
logs-app:
	docker compose logs -f app

.PHONY: logs-db
logs-db:
	docker compose logs -f mariadb

.PHONY: ps
ps:
	docker compose ps

.PHONY: cli
cli:
	@printf "\n$(CYAN)$(BOLD)Entering application container as $(GREEN)www-data$(RESET) $(CYAN)(UID 82) in /app...$(RESET)\n"
	@printf "$(YELLOW)Type 'exit' to return to host shell.$(RESET)\n\n"
	@docker compose exec app sh

.PHONY: wp
wp:
	@if [ -z "$(CMD)" ]; then \
		printf "\n$(YELLOW)$(BOLD)⚠️ No command specified for WP-CLI.$(RESET)\n"; \
		printf "   Usage:   $(CYAN)make wp CMD=\"<command>\"$(RESET)\n"; \
		printf "   Example: $(CYAN)make wp CMD=\"core version\"$(RESET)\n"; \
		printf "   Example: $(CYAN)make wp CMD=\"plugin list\"$(RESET)\n\n"; \
		exit 1; \
	fi
	@docker compose exec app wp $(CMD)

.PHONY: lint
lint: tools lint-php lint-composer lint-shell lint-actions lint-docker lint-yaml lint-security
	@printf "\n$(GREEN)$(BOLD)✓ All 7 quality and security linters passed successfully.$(RESET)\n\n"

.PHONY: lint-php
lint-php:
	@printf "\n$(CYAN)$(BOLD)==> Checking PHP code style with Laravel Pint...$(RESET)\n"
	@$(COMPOSER_RUN) vendor/bin/pint --test

.PHONY: lint-composer
lint-composer:
	@printf "\n$(CYAN)$(BOLD)==> Validating composer.json and composer.lock in strict mode...$(RESET)\n"
	@$(COMPOSER_RUN) composer validate --strict --check-lock --no-check-all

.PHONY: lint-shell
lint-shell: tools
	@printf "\n$(CYAN)$(BOLD)==> Linting shell scripts with standalone ShellCheck...$(RESET)\n"
	@$(TOOLS)/shellcheck -e SC2034 scripts/*.sh
	@printf "$(GREEN)✓ ShellCheck passed.$(RESET)\n"

.PHONY: lint-actions
lint-actions: tools
	@printf "\n$(CYAN)$(BOLD)==> Linting GitHub Actions workflows with standalone actionlint...$(RESET)\n"
	@$(TOOLS)/actionlint
	@printf "$(GREEN)✓ actionlint passed.$(RESET)\n"

.PHONY: lint-docker
lint-docker: tools
	@printf "\n$(CYAN)$(BOLD)==> Linting Dockerfile with standalone hadolint...$(RESET)\n"
	@$(TOOLS)/hadolint --ignore DL3025 --failure-threshold warning Dockerfile
	@printf "$(GREEN)✓ hadolint passed.$(RESET)\n"

.PHONY: lint-yaml
lint-yaml:
	@printf "\n$(CYAN)$(BOLD)==> Linting YAML files with yamllint...$(RESET)\n"
	@$(UV) yamllint .
	@printf "$(GREEN)✓ yamllint passed.$(RESET)\n"

.PHONY: lint-security
lint-security:
	@printf "\n$(CYAN)$(BOLD)==> Auditing GitHub Actions security with zizmor...$(RESET)\n"
	@$(UV) zizmor .
	@printf "$(GREEN)✓ zizmor passed.$(RESET)\n"

.PHONY: format
format:
	@printf "\n$(CYAN)$(BOLD)==> Auto-formatting PHP codebase with Laravel Pint...$(RESET)\n"
	@$(COMPOSER_RUN) vendor/bin/pint
	@printf "$(GREEN)✓ Formatting complete.$(RESET)\n\n"

.PHONY: audit
audit:
	@printf "\n$(CYAN)$(BOLD)==> Auditing Composer dependencies for vulnerabilities...$(RESET)\n"
	@$(COMPOSER_RUN) composer audit
	@printf "$(GREEN)✓ Dependency audit complete.$(RESET)\n\n"

.PHONY: test
test:
	@bash scripts/4-test-security.sh

.PHONY: test-security
test-security: tools
	@printf "\n$(CYAN)$(BOLD)==> Running standalone Trivy vulnerability scan against $(IMAGE_NAME):local...$(RESET)\n"
	@if ! docker image inspect $(IMAGE_NAME):local >/dev/null 2>&1; then \
		printf "$(YELLOW)⚠️ Image $(IMAGE_NAME):local not found. Building first...$(RESET)\n"; \
		$(MAKE) build; \
	fi
	@$(TOOLS)/trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed $(IMAGE_NAME):local
	@printf "$(GREEN)✓ Trivy container scan passed (0 HIGH, 0 CRITICAL).$(RESET)\n\n"

.PHONY: backup
backup:
	@bash scripts/3-backup.sh

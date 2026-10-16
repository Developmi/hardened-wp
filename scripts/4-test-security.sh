#!/usr/bin/env bash
set -Eeuo pipefail

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

BASE_URL="${1:-http://127.0.0.1:${APP_PORT:-8080}}"
FAILED=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Hardened WP Security Test Suite       ${NC}"
echo -e "${BLUE}  Target: ${BASE_URL}${NC}"
echo -e "${BLUE}========================================${NC}"

# ═══════════════════════════════════════════════════════════════════════════
# 1. PREREQUISITES VERIFICATION
# ═══════════════════════════════════════════════════════════════════════════

if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not installed or not in PATH${NC}"
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker Compose is not available${NC}"
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo -e "${RED}❌ curl is not installed or not in PATH${NC}"
    exit 1
fi

if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠️ .env not found, creating from .env.example...${NC}"
    cp .env.example .env
fi

if [ ! -f Caddyfile ]; then
    echo -e "${YELLOW}⚠️ Caddyfile not found, creating from Caddyfile.example...${NC}"
    cp Caddyfile.example Caddyfile
fi

# ═══════════════════════════════════════════════════════════════════════════
# 2. RUNTIME LIFECYCLE MANAGEMENT (EPHEMERAL vs LIVE)
# ═══════════════════════════════════════════════════════════════════════════

# shellcheck disable=SC2329 # Invoked indirectly via trap
cleanup() {
    if [ "${WAS_RUNNING:-0}" -eq 0 ]; then
        echo -e "\n${BLUE}🧹 Cleaning up ephemeral test stack...${NC}"
        docker compose down -v --remove-orphans >/dev/null 2>&1 || true
    fi
}

WAS_RUNNING=0
if docker compose ps --status running -q app 2>/dev/null | grep -q .; then
    WAS_RUNNING=1
    echo -e "${GREEN}✓ Live stack detected. Executing tests against running instance...${NC}"
else
    echo -e "${YELLOW}⚠️ Application container is not running. Booting ephemeral test stack...${NC}"
    trap cleanup EXIT INT TERM
    docker compose up -d --build

    echo -e "⏳ Waiting for stack to become healthy..."
    MAX_RETRIES=40
    RETRY_COUNT=0
    while [ "$RETRY_COUNT" -lt "$MAX_RETRIES" ]; do
        APP_HEALTH="$(docker inspect -f '{{.State.Health.Status}}' bedrock_app 2>/dev/null || echo 'starting')"
        DB_HEALTH="$(docker inspect -f '{{.State.Health.Status}}' bedrock_db 2>/dev/null || echo 'starting')"

        if [ "$APP_HEALTH" = "healthy" ] && [ "$DB_HEALTH" = "healthy" ]; then
            echo -e "${GREEN}✓ Ephemeral stack is healthy and ready.${NC}"
            break
        fi

        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
            echo -e "${RED}❌ Stack failed to become healthy within timeout (app: ${APP_HEALTH}, db: ${DB_HEALTH})${NC}"
            docker compose logs
            exit 1
        fi
        sleep 1
    done
fi

# ═══════════════════════════════════════════════════════════════════════════
# 3. HTTP PROBES & ASSERTIONS
# ═══════════════════════════════════════════════════════════════════════════

probe() {
    local path="$1"
    local expected="$2"
    local desc="$3"
    local url="${BASE_URL}${path}"

    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null) || status="000"
    if [ -z "$status" ]; then
        status="000"
    fi

    case "$expected" in
        "200")
            if [ "$status" = "200" ]; then
                echo -e "  [${GREEN}PASS${NC}] ${path} -> ${status} (${desc})"
            else
                echo -e "  [${RED}FAIL${NC}] ${path} -> expected 200, got ${status} (${desc})"
                FAILED=1
            fi
            ;;
        "200_OR_302")
            if [ "$status" = "200" ] || [ "$status" = "302" ]; then
                echo -e "  [${GREEN}PASS${NC}] ${path} -> ${status} (${desc})"
            else
                echo -e "  [${RED}FAIL${NC}] ${path} -> expected 200 or 302, got ${status} (${desc})"
                FAILED=1
            fi
            ;;
        "403")
            if [ "$status" = "403" ]; then
                echo -e "  [${GREEN}PASS${NC}] ${path} -> ${status} (${desc})"
            else
                echo -e "  [${RED}FAIL${NC}] ${path} -> expected 403, got ${status} (${desc})"
                FAILED=1
            fi
            ;;
        "403_OR_404")
            if [ "$status" = "403" ] || [ "$status" = "404" ]; then
                echo -e "  [${GREEN}PASS${NC}] ${path} -> ${status} (${desc})"
            else
                echo -e "  [${RED}FAIL${NC}] ${path} -> expected 403 or 404 (non-200), got ${status} (${desc})"
                FAILED=1
            fi
            ;;
        *)
            echo -e "  [${RED}FAIL${NC}] Unknown expectation: ${expected}"
            FAILED=1
            ;;
    esac
}

echo -e "\n${YELLOW}3. Probing HTTP endpoints...${NC}"
probe "/healthz" "200" "health check"
probe "/" "200_OR_302" "root index"
probe "/app/uploads/malicious.php" "403" "blocked direct PHP execution in uploads"
probe "/wp-config.php" "403" "blocked wp-config.php access"
probe "/xmlrpc.php" "403" "blocked XML-RPC endpoint"
probe "/backup.sql" "403" "blocked SQL dump file access"
probe "/.env" "403_OR_404" "blocked .env secret access"

# ═══════════════════════════════════════════════════════════════════════════
# 4. CONTAINER SECURITY IDENTITY
# ═══════════════════════════════════════════════════════════════════════════

echo -e "\n${YELLOW}4. Inspecting container execution user...${NC}"
APP_ID_OUTPUT=$(docker compose exec -T app id 2>&1 || true)
if echo "$APP_ID_OUTPUT" | grep -q "uid=82(www-data)"; then
    echo -e "  [${GREEN}PASS${NC}] Container user: ${APP_ID_OUTPUT}"
else
    echo -e "  [${RED}FAIL${NC}] Container user is not uid=82(www-data): ${APP_ID_OUTPUT}"
    FAILED=1
fi

echo ""
if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}✓ All security assertions passed successfully.${NC}\n"
    exit 0
else
    echo -e "${RED}✗ One or more security assertions failed.${NC}\n"
    exit 1
fi

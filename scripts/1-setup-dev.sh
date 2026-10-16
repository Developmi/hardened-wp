#!/usr/bin/env bash
set -Eeuo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "🚀 Bedrock Docker - Development Setup"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# 1. VALIDATE .env AND Caddyfile
# ═══════════════════════════════════════════════════════════════════════════

if [ ! -f .env ]; then
    echo -e "${RED}❌ .env file not found${NC}"
    echo ""
    echo "📋 Create it from the template:"
    echo "   cp .env.example .env"
    echo "   Then edit .env with your values"
    exit 1
fi

echo "✅ .env file found"

if [ ! -f Caddyfile ]; then
    echo -e "${YELLOW}⚠️ Caddyfile not found, creating from Caddyfile.example...${NC}"
    cp Caddyfile.example Caddyfile
fi

echo "✅ Caddyfile ready"

# Validate required variables exist
REQUIRED_VARS=("MARIADB_ROOT_PASSWORD" "DATABASE_URL")
for var in "${REQUIRED_VARS[@]}"; do
    if ! grep -q "^${var}=" .env; then
        echo -e "${RED}❌ Missing required variable: ${var}${NC}"
        exit 1
    fi
done

echo "✅ Required environment variables present"

get_env_value() {
    local key="$1"
    awk -F= -v k="$key" '
        $1==k {
            sub(/^[[:space:]]+|[[:space:]]+$/, "", $2)
            gsub(/^"|"$/, "", $2)
            gsub(/^'\''|'\''$/, "", $2)
            print $2
            exit
        }' .env
}

# ═══════════════════════════════════════════════════════════════════════════
# 2. VALIDATE DOCKER
# ═══════════════════════════════════════════════════════════════════════════

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker Compose is not available${NC}"
    exit 1
fi

echo "✅ Docker and Docker Compose available"

# ═══════════════════════════════════════════════════════════════════════════
# 3. BUILD AND START CONTAINERS
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo "🐳 Building image and starting containers..."
docker compose up -d --build

# ═══════════════════════════════════════════════════════════════════════════
# 4. WAIT FOR MARIADB
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo "⏳ Waiting for MariaDB to be ready..."

MAX_RETRIES=60
RETRY_DELAY=2
RETRY_COUNT=0

until docker compose exec -T mariadb \
    mariadb-admin ping \
    -u root \
    -p"$(get_env_value MARIADB_ROOT_PASSWORD)" \
    --silent >/dev/null 2>&1; do

    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
        echo -e "${RED}❌ MariaDB did not become ready in time${NC}"
        echo ""
        echo "📋 Check logs: docker compose logs mariadb"
        exit 1
    fi

    if [ $((RETRY_COUNT % 10)) -eq 0 ]; then
        echo "   Still waiting... (${RETRY_COUNT}s)"
    fi

    sleep "$RETRY_DELAY"
done

echo "✅ MariaDB is ready"

# ═══════════════════════════════════════════════════════════════════════════
# 5. DONE
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✅ Bedrock is running${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo ""
echo "📍 Complete WordPress installation:"
echo -e "   ${BLUE}http://localhost:8080${NC}"
echo ""
echo "🔧 Useful commands:"
echo "   docker compose logs -f app       # App logs"
echo "   docker compose exec app wp ...   # WP-CLI"
echo "   docker compose down              # Stop"
echo "   docker compose down -v           # Stop + wipe DB"

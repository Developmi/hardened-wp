#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# Define the path where backups will be stored
BACKUP_DIR="./backups"
DATE="$(date +%F_%H-%M-%S)"

mkdir -p "${BACKUP_DIR}"

echo "💾 Starting backup process..."

# 1. Database backup
# Read credentials directly from .env to avoid hardcoding
if [ ! -f .env ]; then
	echo "❌ .env not found"
	exit 1
fi

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

DB_USER="$(get_env_value MARIADB_USER)"
DB_PASS="$(get_env_value MARIADB_PASSWORD)"
DB_NAME="$(get_env_value MARIADB_DATABASE)"

for var in DB_USER DB_PASS DB_NAME; do
	if [ -z "${!var:-}" ]; then
		echo "❌ Missing ${var} in .env"
		exit 1
	fi
done

# Run the dump inside the database container
TMP_SQL="${BACKUP_DIR}/db_${DATE}.sql.tmp"
FINAL_SQL_GZ="${BACKUP_DIR}/db_${DATE}.sql.gz"

docker exec -e MYSQL_PWD="${DB_PASS}" bedrock_db \
	mariadb-dump -u"${DB_USER}" --single-transaction --quick --lock-tables=false "${DB_NAME}" > "${TMP_SQL}"

gzip -c "${TMP_SQL}" > "${FINAL_SQL_GZ}"
rm -f "${TMP_SQL}"
echo "✅ Database backed up: db_${DATE}.sql.gz"

# 2. Uploads backup
docker compose exec -T app tar -czf - -C /app/web/app uploads > "${BACKUP_DIR}/uploads_${DATE}.tar.gz"
echo "✅ Files backed up: uploads_${DATE}.tar.gz"

# 3. Checksums
(
	cd "${BACKUP_DIR}"
	sha256sum "db_${DATE}.sql.gz" "uploads_${DATE}.tar.gz" > "backup_${DATE}.sha256"
)
echo "✅ Checksum generated: backup_${DATE}.sha256"

# 4. Retention (prune backups older than 14 days)
find "${BACKUP_DIR}" -type f \( -name "*.gz" -o -name "*.sha256" \) -mtime +14 -delete
echo "✅ Pruned backups older than 14 days"

echo "🎉 Backup completed successfully in $BACKUP_DIR"

# Disaster Recovery Runbook

This runbook defines the exact operational procedure for restoring **Bedrock Ship** state (both relational database and user media uploads) from cold backup archives with cryptographic SHA-256 integrity validation.

---

## 1. Recovery Objectives & Parameters

| Metric | Target | Description |
| :--- | :--- | :--- |
| **RPO (Recovery Point Objective)** | $\le$ 24 hours | Maximum acceptable data loss period (dependent on cron backup frequency). |
| **RTO (Recovery Time Objective)** | < 15 minutes | Maximum allowable downtime during an authorized full-restore invocation. |
| **Integrity Standard** | Strict SHA-256 | No archive will be unpacked or imported without checksum manifest verification. |

---

## 2. Backup Archive Structure

Backups produced by `scripts/3-backup.sh` (or `make backup`) reside in `./backups/` and follow this naming schema:

```
backups/
├── db_YYYY-MM-DD_HH-MM-SS.sql.gz        # Compressed MariaDB SQL dump
├── uploads_YYYY-MM-DD_HH-MM-SS.tar.gz   # Compressed WordPress uploads archive
└── backup_YYYY-MM-DD_HH-MM-SS.sha256    # Cryptographic SHA-256 manifest
```

---

## 3. Step-by-Step Recovery Procedure

### Step 1: Select and Verify Backup Manifest

Identify the target timestamp (e.g. `2026-10-15_02-00-00`):

```bash
export TARGET_DATE="2026-10-15_02-00-00"
cd backups
```

Verify the cryptographic SHA-256 manifest before touching any data:

```bash
sha256sum -c "backup_${TARGET_DATE}.sha256"
```

Expected output:
```
db_2026-10-15_02-00-00.sql.gz: OK
uploads_2026-10-15_02-00-00.tar.gz: OK
```

> [!CAUTION]
> If `sha256sum -c` fails with `FAILED`, **DO NOT PROCEED**. The archive is corrupted or tampered with. Locate an earlier valid manifest.

Return to the repository root:
```bash
cd ..
```

---

### Step 2: Quiesce Application Traffic

Prevent concurrent writes during restoration by scaling the app down or putting ingress in maintenance:

```bash
# Stop application container while keeping database active
docker compose stop app
```

Verify MariaDB is healthy:
```bash
docker compose ps mariadb
```

---

### Step 3: Database Restoration

1. Extract database credentials securely from `.env`:
   ```bash
   get_env() { awk -F= -v k="$1" '$1==k {gsub(/^["'\'' ]+|["'\'' ]+$/, "", $2); print $2; exit}' .env; }
   DB_USER=$(get_env MARIADB_USER)
   DB_PASS=$(get_env MARIADB_PASSWORD)
   DB_NAME=$(get_env MARIADB_DATABASE)
   ```

2. Drop and recreate the database schema to ensure clean slate:
   ```bash
   docker exec -e MYSQL_PWD="${DB_PASS}" bedrock_db \
     mariadb -u"${DB_USER}" -e "DROP DATABASE IF EXISTS \`${DB_NAME}\`; CREATE DATABASE \`${DB_NAME}\`;"
   ```

3. Stream and decompress the backup archive directly into MariaDB:
   ```bash
   gunzip -c "backups/db_${TARGET_DATE}.sql.gz" | \
     docker exec -i -e MYSQL_PWD="${DB_PASS}" bedrock_db mariadb -u"${DB_USER}" "${DB_NAME}"
   ```

4. Verify database tables:
   ```bash
   docker exec -e MYSQL_PWD="${DB_PASS}" bedrock_db \
     mariadb -u"${DB_USER}" -e "SHOW TABLES IN \`${DB_NAME}\`;"
   ```

---

### Step 4: Media Uploads Restoration

The user media uploads are stored in the named Docker volume `wp_uploads` mounted at `/app/web/app/uploads`.

1. Purge existing corrupt or stale files inside the volume:
   ```bash
   docker compose run --rm --entrypoint "" app sh -c "rm -rf /app/web/app/uploads/* /app/web/app/uploads/.[!.]*"
   ```

2. Restore media archive contents into the `wp_uploads` volume:
   ```bash
   docker compose run --rm -v "$(pwd)/backups:/backups:ro" --entrypoint "" app \
     sh -c "tar -xzf /backups/uploads_${TARGET_DATE}.tar.gz -C /app/web/app"
   ```

3. Enforce strict non-root ownership (`82:82` for `www-data`):
   ```bash
   docker compose run --rm --entrypoint "" -u 0 app \
     sh -c "chown -R 82:82 /app/web/app/uploads /app/web/app/cache && chmod -R 775 /app/web/app/uploads /app/web/app/cache"
   ```

---

### Step 5: Start Application & Clear Caches

1. Start the application container:
   ```bash
   docker compose up -d app
   ```

2. Wait for application container health probe:
   ```bash
   until curl -s -f http://127.0.0.1:8080/healthz >/dev/null; do
     echo "Waiting for app health probe..."
     sleep 2
   done
   echo "App is healthy."
   ```

3. Flush WordPress object caches and verify database schema integrity via WP-CLI:
   ```bash
   make wp CMD="db check"
   make wp CMD="cache flush"
   ```

---

## 4. Post-Restoration Sanity Checklist

- [ ] `make test` returns HTTP 200 from `/healthz`.
- [ ] Database tables are intact (`make wp CMD="db tables"`).
- [ ] Media files are visible in WordPress admin media library.
- [ ] Uploading a new image via WordPress admin succeeds.
- [ ] Front-end renders without missing assets or 500 errors.
- [ ] SHA-256 verified backup timestamp recorded in incident log.

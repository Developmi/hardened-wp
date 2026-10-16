# Incident Response Runbook

This runbook defines operational triage procedures, containment workflows, and remediation playbooks for production incidents affecting **Bedrock Ship** deployments.

---

## 1. Severity Classification Matrix

| Severity | Definition | Target MTTR | Escalation Trigger |
| :--- | :--- | :--- | :--- |
| **SEV-1 (Critical)** | Application completely unavailable, database unreachable, or active security exploit. | < 30 minutes | PagerDuty / Immediate On-call alert |
| **SEV-2 (Major)** | Core functionality degraded, persistent 5xx error spikes (> 5%), or backup failure. | < 2 hours | Engineering Lead notification |
| **SEV-3 (Minor)** | Non-blocking issues, single background task failure, minor warning spikes. | < 8 hours | Next-business-day ticket |

---

## 2. Standard Triage Protocol

Follow the four-step incident lifecycle:

```
[1. DETECT & ASSESS] ──> [2. CONTAIN & MITIGATE] ──> [3. ROOT CAUSE] ──> [4. POST-MORTEM]
```

### Initial Diagnostic Assessment

Execute the diagnostic sweep within the project root:

```bash
# 1. Check container runtime state and restart counts
docker compose ps

# 2. Inspect real-time resource utilization (CPU, memory, PIDs)
docker stats --no-stream

# 3. Check application health probe
curl -Iv http://127.0.0.1:8080/healthz

# 4. Tail recent error logs across all services
docker compose logs --tail=100
```

---

## 3. Incident Scenarios & Remediation Playbooks

### Scenario A: Container CrashLoop (`bedrock_app` failing to boot)

#### Symptoms
- `docker compose ps` shows `bedrock_app` with status `Restarting (X) ...`
- HTTP 502 Bad Gateway at ingress or reverse proxy.

#### Triage Steps
1. Inspect the dying container logs immediately:
   ```bash
   docker compose logs --tail=200 app
   ```
2. Common root causes and signatures:
   - **Missing Environment Variables**:
     ```
     Error: DATABASE_URL is required in .env
     Error: AUTH_KEY is required in .env
     ```
     *Fix*: Validate `.env` against `.env.example`. Verify all 8 security salts and database credentials exist.
   - **Permission Denied in Caddy / Storage**:
     ```
     open /data/caddy/...: permission denied
     open /app/web/app/uploads/...: permission denied
     ```
     *Fix*: Ensure storage volumes and bind mounts are owned by UID/GID `82:82` (`www-data`):
     ```bash
     docker compose exec -u 0 app chown -R 82:82 /app/web/app/uploads /app/web/app/cache /data /config
     ```
   - **Caddyfile Syntax Error**:
     ```
     run: adapting config using caddyfile: ...
     ```
     *Fix*: Validate Caddy configuration syntax:
     ```bash
     docker compose run --rm --entrypoint frankenphp app validate --config /etc/frankenphp/Caddyfile
     ```

---

### Scenario B: MariaDB Connection Failure & Socket Exhaustion

#### Symptoms
- Web application displays `Error establishing a database connection`.
- WordPress logs display `mysqli_real_connect(): (HY000/2002): Connection refused` or `Too many connections`.

#### Triage Steps
1. Verify MariaDB container health:
   ```bash
   docker compose ps mariadb
   docker compose logs --tail=100 mariadb
   ```
2. Test database connection directly inside the stack:
   ```bash
   docker compose exec mariadb mariadb-admin ping -u root -p
   ```
3. Check active database thread count and processlist:
   ```bash
   docker compose exec mariadb mariadb -u root -p -e "SHOW STATUS LIKE 'Threads_connected';"
   docker compose exec mariadb mariadb -u root -p -e "SHOW PROCESSLIST;"
   ```

#### Remediation Steps
- **Zombie / Sleeping Queries**: Kill long-running runaway queries:
  ```sql
  KILL <process_id>;
  ```
- **Connection Limit Reached**: If connections peaked due to traffic, inspect `max_connections` (default 151). If system memory permits, adjust in MariaDB config or restart MariaDB container:
  ```bash
  docker compose restart mariadb
  ```
- **Memory Pressure / OOM**: Verify if MariaDB was killed by Linux OOM killer:
  ```bash
  dmesg -T | grep -i -E "oom[- ]killer|mariadbd"
  ```
  If OOM killed MariaDB, raise the container memory limit in `docker-compose.yml` (`deploy.resources.limits.memory`).

---

### Scenario C: Automated Backup Failures (`scripts/3-backup.sh`)

#### Symptoms
- Scheduled backup cron job logs exit status `1`.
- Missing daily `db_*.sql.gz` or `uploads_*.tar.gz` in `./backups`.

#### Triage Steps
1. Execute the backup script manually with bash trace enabled:
   ```bash
   bash -x scripts/3-backup.sh
   ```
2. Check available host disk space:
   ```bash
   df -h . ./backups
   ```
   *Failure Signature*: `gzip: stdout: No space left on device` or `tar: Write error`.
3. Check `.env` readability:
   The script requires `MARIADB_USER`, `MARIADB_PASSWORD`, and `MARIADB_DATABASE` defined in `.env`.

#### Remediation Steps
- Free disk space by manually pruning archives older than retention window:
  ```bash
  find ./backups -type f \( -name "*.gz" -o -name "*.sha256" \) -mtime +14 -delete
  ```
- Verify backup archive integrity:
  ```bash
  cd backups && sha256sum -c backup_<DATE>.sha256
  ```

---

### Scenario D: PHP Fatal Error Surges & Worker Starvation

#### Symptoms
- Ingress logs report intermittent `504 Gateway Timeout` or `500 Internal Server Error`.
- High CPU utilization or container restart spikes.

#### Triage Steps
1. Stream live PHP error log from the container stderr:
   ```bash
   make logs-app | grep -E "PHP Fatal error|Allowed memory size|Maximum execution time"
   ```
2. Check memory usage per worker:
   ```bash
   docker stats bedrock_app --no-stream
   ```
3. Identify problematic plugins or themes:
   ```bash
   make wp CMD="plugin list --status=active"
   ```

#### Remediation Steps
- **Emergency Plugin Deactivation**: If a faulty plugin or update causes a fatal crashloop:
  ```bash
  make wp CMD="plugin deactivate <faulty-plugin-slug>"
  ```
- **Flush Caches**: Flush Acorn and WordPress object caches:
  ```bash
  make wp CMD="cache flush"
  make wp CMD="transient delete --all"
  ```
- **Memory Limit Adjustment**: If fatal memory errors occur (`Allowed memory size of 268435456 bytes exhausted`), evaluate if temporary increase is required in `/usr/local/etc/php/conf.d/uploads.ini` or optimize database queries.

---

## 4. Post-Incident Review Protocol

For all SEV-1 and SEV-2 incidents, submit a Post-Incident Review (PIR) within 48 hours containing:
1. **Executive Summary**: Timeline of outage and impact.
2. **Root Cause Analysis (RCA)**: 5-Whys methodology.
3. **Corrective & Preventive Actions (CAPA)**: Action items assigned with pull requests or runbook updates.

#!/usr/bin/env bash
# Dumps every database in Postgres (one per Backstage plugin) into backups/<time>.sql.
source "$(dirname "$0")/lib.sh"
require_cluster

mkdir -p "${BACKUP_DIR}"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
file="${BACKUP_DIR}/${stamp}.sql"

info "pg_dumpall --clean: every Backstage database, plus the roles"
show "kubectl -n ${NS} exec postgres-0 -- pg_dumpall --clean --if-exists > backups/${stamp}.sql"
kubectl -n "${NS}" exec postgres-0 -- pg_dumpall --clean --if-exists >"${file}.partial"
mv "${file}.partial" "${file}"

ok "Backup written: backups/$(basename "${file}") ($(du -h "${file}" | cut -f1 | xargs))"
bold "Backup time: $(date +%H:%M:%S). Write it down: everything after this moment is at risk."

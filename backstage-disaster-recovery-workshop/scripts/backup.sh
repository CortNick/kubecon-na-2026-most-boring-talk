#!/usr/bin/env bash
# Dumps every database in Postgres (one per Backstage plugin) into backups/<time>.sql.
source "$(dirname "$0")/lib.sh"
require_cluster

mkdir -p "${BACKUP_DIR}"
file="backups/$(date -u +%Y%m%dT%H%M%SZ).sql"

info "pg_dumpall --clean: every Backstage database, plus the roles"
sh_exec "kubectl -n ${NS} exec postgres-0 -- pg_dumpall --clean --if-exists > ${file}" \
  || { rm -f "${ROOT_DIR}/${file}"; fail "The backup failed; no file was kept."; }

ok "Backup written: ${file} ($(du -h "${ROOT_DIR}/${file}" | cut -f1 | xargs))"
bold "Backup time: $(date +%H:%M:%S). Write it down: everything after this moment is at risk."

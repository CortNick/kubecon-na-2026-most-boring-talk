#!/usr/bin/env bash
# The recovery runbook: stop Backstage, start a fresh Postgres, load the newest backup,
# start Backstage again.
source "$(dirname "$0")/lib.sh"
require_cluster

backup="$(newest_backup)"
[[ -n "${backup}" ]] || fail "No backup in backups/. Did you run 'make backup' in Part 1?"
rel="backups/$(basename "${backup}")"

start=$(date +%s)
bold "Restoring ${rel}"

info "Step 1/4: stop Backstage, so nothing writes while we restore"
run kubectl -n "${NS}" scale deploy/backstage --replicas=0
run kubectl -n "${NS}" wait --for=delete pod -l app=backstage --timeout=120s >/dev/null 2>&1 || true

info "Step 2/4: start a fresh, empty Postgres on a new disk"
fresh_postgres

info "Step 3/4: load the backup with psql"
# The dump also drops and recreates the 'backstage' role, which psql is connected as.
# Skip those two lines; the fresh Postgres already has that role.
skip_roles='^(DROP ROLE IF EXISTS|CREATE ROLE) backstage;$'
sh_exec "grep -vE '${skip_roles}' ${rel} | kubectl -n ${NS} exec -i postgres-0 -- env PGOPTIONS='-c client_min_messages=warning' psql -q -v ON_ERROR_STOP=1 -d postgres > /dev/null"

info "Step 4/4: start Backstage"
run kubectl -n "${NS}" scale deploy/backstage --replicas=1
wait_for_backstage
wait_for_catalog

echo
ok "Restored in $(( $(date +%s) - start ))s"

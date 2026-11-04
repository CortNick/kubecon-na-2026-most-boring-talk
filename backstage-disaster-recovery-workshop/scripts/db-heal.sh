#!/usr/bin/env bash
# Fixes the network between Backstage and Postgres: a fresh db-proxy, no latency, enabled.
# Backstage is NOT restarted: it reconnects by itself.
source "$(dirname "$0")/lib.sh"
require_cluster

start=$(date +%s)
info "Replace the db-proxy with a fresh one (no toxics, connections allowed)"
run kubectl -n "${NS}" rollout restart deploy/db-proxy
wait_for_db_proxy
show "curl -sf ${API}/api/catalog/entities/by-query?limit=1     # repeated until the API answers"
for _ in $(seq 1 60); do
  [[ "$(entity_count)" =~ ^[0-9]+$ ]] && break
  sleep 1
done
ok "The API answers again after $(( $(date +%s) - start ))s, without restarting Backstage."
echo
bold "# Did we lose anything? (11 entities and 2 tasks before)"
sh_run "curl -sf --max-time 10 '${API}/api/catalog/entities/by-query?limit=1' | jq .totalItems"
sh_run "curl -sf --max-time 10 ${API}/api/scaffolder/v2/tasks | jq '.tasks | length'"
echo
warn "Reload the portal: everything is back. Slow and unreachable cost you time, not data."

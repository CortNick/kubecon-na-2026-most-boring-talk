#!/usr/bin/env bash
# Kills the Backstage pod. The Deployment starts a new one; nothing is lost,
# because Backstage keeps nothing itself: it is all in Postgres and in config.
source "$(dirname "$0")/lib.sh"
require_cluster

echo
bold "💥  The Backstage pod just died  💥"
echo
start=$(date +%s)
info "Delete the pod. Its Deployment notices and starts a new one"
run kubectl -n "${NS}" delete pod -l app=backstage --wait=false
run kubectl -n "${NS}" get pods -l app=backstage
wait_for_backstage
wait_for_catalog
ok "Backstage is back in $(( $(date +%s) - start ))s, on the same database."
echo
bold "# Did we lose anything? (11 entities and 2 tasks before)"
sh_run "curl -sf --max-time 10 '${API}/api/catalog/entities/by-query?limit=1' | jq .totalItems"
sh_run "curl -sf --max-time 10 ${API}/api/scaffolder/v2/tasks | jq '.tasks | length'"
echo
warn "Reload the portal: same catalog, same tasks. You may have to select ENTER under Guest again."

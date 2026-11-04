#!/usr/bin/env bash
# Restarts Backstage. It creates its databases and tables only when it starts,
# so after the database is replaced it has to be restarted to work again.
source "$(dirname "$0")/lib.sh"
require_cluster

start=$(date +%s)
info "Restarting Backstage: Kubernetes replaces its pod with a new one"
run kubectl -n "${NS}" rollout restart deploy/backstage
wait_for_backstage
wait_for_catalog
ok "Backstage is back in $(( $(date +%s) - start ))s, on an empty database."
echo
warn "Look in the portal: which of your things came back, and which did not?"

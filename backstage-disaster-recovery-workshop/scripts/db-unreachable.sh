#!/usr/bin/env bash
# Cuts the network between Backstage and Postgres. Postgres and its disk are untouched.
source "$(dirname "$0")/lib.sh"
require_cluster

echo
bold "🔌  Backstage can no longer reach the database  🔌"
echo
info "Add a 'timeout' toxic with timeout=0: every byte to Postgres vanishes, like a network partition"
toxiproxy toxic add -t timeout -n unreachable -a timeout=0 postgres \
  || warn "It is already unreachable. Run 'make db-heal' to fix it."
echo
bold "# Is Postgres still fine? (yes: it just can't be reached)"
sh_run "kubectl -n ${NS} exec postgres-0 -- pg_isready"
echo
bold "# Does the API answer? (curl gives up after 10 seconds)"
sh_run "curl -sf --max-time 10 '${API}/api/catalog/entities/by-query?limit=1' | jq .totalItems"
echo
bold "# And what does Kubernetes think?"
sh_run "kubectl -n ${NS} get pods -l app=backstage"
echo
warn "Reload the portal: the page loads (static files), but every API call hangs, then fails."
warn "The Backstage pod is still Ready. Nothing restarts it, and restarting it would not help."
warn "Next: 'make db-heal'."

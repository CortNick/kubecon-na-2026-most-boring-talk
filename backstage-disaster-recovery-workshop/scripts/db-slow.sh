#!/usr/bin/env bash
# Makes the database slow: every reply from Postgres to Backstage is held back for LATENCY ms.
# Usage: make db-slow [LATENCY=1000]
source "$(dirname "$0")/lib.sh"
require_cluster
latency="${LATENCY:-1000}"

echo
bold "🐢  The database just got slow: +${latency}ms on every reply  🐢"
echo
info "Add a latency 'toxic' to the db-proxy between Backstage and Postgres"
toxiproxy toxic add -t latency -n slow -a "latency=${latency}" postgres \
  || warn "It is already slow. Run 'make db-heal' to reset it."
toxiproxy inspect postgres
echo
bold "# How long does one API call take now?"
sh_run "time curl -sf --max-time 30 -o /dev/null -w '%{http_code}\n' '${API}/api/catalog/entities/by-query?limit=1'"
echo
bold "# And what does Kubernetes think?"
sh_run "kubectl -n ${NS} get pods -l app=backstage"
echo
warn "Click around the portal: Catalog, a component, Create > Tasks. Everything works, slowly."
warn "The pod is still Ready: Kubernetes has no idea your users are waiting."
warn "Next: 'make db-unreachable'."

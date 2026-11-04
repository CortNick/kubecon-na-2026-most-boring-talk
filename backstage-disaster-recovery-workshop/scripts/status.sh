#!/usr/bin/env bash
# Shows the state of the lab, one plain command at a time: what Kubernetes sees,
# and what the Backstage API returns. Copy any line after '$' to run it yourself.
source "$(dirname "$0")/lib.sh"
require_cluster

bold "# Is everything running? (what Kubernetes sees)"
sh_run "kubectl -n ${NS} get pods"
echo
bold "# How many catalog entities does the API return?"
sh_run "curl -sf --max-time 10 '${API}/api/catalog/entities/by-query?limit=1' | jq .totalItems"
echo
bold "# How many template runs (scaffolder tasks)?"
sh_run "curl -sf --max-time 10 ${API}/api/scaffolder/v2/tasks | jq '.tasks | length'"
echo
bold "# How many components were registered through the portal?"
sh_run "curl -sf --max-time 10 ${API}/api/catalog/locations | jq 'map(select(.data.type == \"url\")) | length'"
echo
bold "# Which backups do we have?"
sh_run "ls backups/"

#!/usr/bin/env bash
# Shows the two pods the lab is about: Backstage and the Postgres it stores everything in.
source "$(dirname "$0")/lib.sh"
require_cluster

info "What runs in the '${NS}' namespace"
run kubectl -n "${NS}" get pods -l 'app in (backstage,postgres)'
echo
printf '  %-14s %s\n' "backstage-..." "The portal and its API. Stateless: Kubernetes can replace it any time."
printf '  %-14s %s\n' "postgres-0"    "The database, on its own disk. The only place Backstage keeps state."

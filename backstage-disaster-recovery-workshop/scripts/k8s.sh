#!/usr/bin/env bash
# Shows the pods the lab is about: Backstage, the Postgres it stores everything in,
# and the lab's stand-in for the network between them.
source "$(dirname "$0")/lib.sh"
require_cluster

info "What runs in the '${NS}' namespace"
run kubectl -n "${NS}" get pods -l 'app in (backstage,postgres,db-proxy)'
echo
printf '  %-14s %s\n' "backstage-..." "The portal and its API. Stateless: Kubernetes can replace it any time."
printf '  %-14s %s\n' "postgres-0"    "The database, on its own disk. The only place Backstage keeps state."
printf '  %-14s %s\n' "db-proxy-..."  "LAB ONLY: the network between them, so the lab can make it slow or cut it."

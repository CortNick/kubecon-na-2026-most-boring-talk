#!/usr/bin/env bash
# Shows every pod in the lab's namespace: Backstage, the Postgres it stores everything in,
# the lab's stand-in for the network between them, and the legacy billing sample workload.
source "$(dirname "$0")/lib.sh"
require_cluster

info "What runs in the '${NS}' namespace"
run kubectl -n "${NS}" get pods
echo
printf '  %-18s %s\n' "backstage-..."      "The portal and its API. Stateless: Kubernetes can replace it any time."
printf '  %-18s %s\n' "postgres-0"         "The database, on its own disk. The only place Backstage keeps state."
printf '  %-18s %s\n' "db-proxy-..."       "LAB ONLY: the network between them, so the lab can make it slow or cut it."
printf '  %-18s %s\n' "legacy-billing-..." "A sample legacy billing workload, built by one of our developer teams. Used later in the lab."

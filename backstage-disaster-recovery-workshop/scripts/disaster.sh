#!/usr/bin/env bash
# Simulates losing the database disk: deletes the Postgres volume and its pod.
# The StatefulSet then starts a new, empty Postgres on a new volume.
source "$(dirname "$0")/lib.sh"
require_cluster

echo
bold "🔥🔥🔥  The Postgres disk just died  🔥🔥🔥"
echo
date +%s >"${DISASTER_MARKER}"

info "Simulating the failure: stop Postgres, delete its disk (the PersistentVolumeClaim), start it again"
fresh_postgres

echo
ok "A new Postgres is running, on a new, EMPTY disk."
warn "Backstage is still running, but everything it stored is gone."
warn "Reload the portal: it fails until Backstage is restarted ('make restart-backend')."

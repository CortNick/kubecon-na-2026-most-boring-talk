#!/usr/bin/env bash
# Puts the lab back to the state right after 'make setup', without recreating the cluster:
# deletes the namespace (Backstage, Postgres and its disk, the db-proxy) and the backups.
source "$(dirname "$0")/lib.sh"
require_cluster

start=$(date +%s)
info "Deleting everything in the '${NS}' namespace, including the Postgres disk"
kubectl delete namespace "${NS}" --ignore-not-found --wait=true >/dev/null
rm -rf "${BACKUP_DIR}"

info "Starting Postgres and Backstage again"
"${ROOT_DIR}/scripts/render-tour.sh"
apply_lab
ok "Reset done in $(( $(date +%s) - start ))s. Portal: $(base_url)"

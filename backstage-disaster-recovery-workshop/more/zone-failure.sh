#!/usr/bin/env bash
# Stretch exercise: lose an availability zone instead of a disk.
# Usage: more/zone-failure.sh up          create the two-zone cluster and start Backstage (2 replicas)
#        more/zone-failure.sh fail [zone] cordon and drain one zone (default: the one WITHOUT Postgres)
#        more/zone-failure.sh heal        uncordon every zone
#        more/zone-failure.sh status      where everything runs, and is the portal up
#        more/zone-failure.sh down        delete the two-zone cluster
source "$(dirname "$0")/../scripts/lib.sh"

# Same helpers as the lab, pointed at the second cluster.
CLUSTER_NAME="backstage-zones"
API="http://localhost:7008"
base_url() {
  if [[ -n "${CODESPACE_NAME:-}" && -n "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" ]]; then
    echo "https://${CODESPACE_NAME}-7008.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
  else
    echo "http://localhost:7008"
  fi
}
MORE_DIR="${ROOT_DIR}/more"

use_cluster() {
  kubectl config use-context "kind-${CLUSTER_NAME}" >/dev/null 2>&1 \
    || fail "No two-zone cluster. Run 'more/zone-failure.sh up' first."
}

zone_of_pod() { # zone_of_pod POD
  local node
  node="$(kubectl -n "${NS}" get pod "$1" -o jsonpath='{.spec.nodeName}')"
  kubectl get node "${node}" -o jsonpath='{.metadata.labels.topology\.kubernetes\.io/zone}'
}

show_state() {
  echo
  kubectl get nodes -L topology.kubernetes.io/zone
  echo
  kubectl -n "${NS}" get pods -o wide | awk '{print $1, $2, $3, $7}' | column -t
  echo
  if api_get '/api/catalog/entities/by-query?limit=1' >/dev/null 2>&1; then
    ok "Portal is UP ($(entity_count) catalog entities)"
  else
    warn "Portal is DOWN"
  fi
}

case "${1:-}" in
  up)
    if ! kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
      info "Creating the two-zone kind cluster '${CLUSTER_NAME}'"
      kind create cluster --name "${CLUSTER_NAME}" --image "${KIND_NODE_IMAGE}" \
        --config "${MORE_DIR}/kind-config-zones.yaml" --wait 120s
    fi
    use_cluster
    # kind keeps the control-plane taint when a cluster has workers; zone-a must take workloads too.
    kubectl taint nodes -l topology.kubernetes.io/zone=zone-a node-role.kubernetes.io/control-plane:NoSchedule- >/dev/null 2>&1 || true
    info "Starting Postgres and Backstage"
    apply_manifest namespace.yaml
    apply_config
    apply_manifest postgres.yaml
    apply_manifest legacy-billing.yaml
    wait_for_postgres
    apply_manifest db-proxy.yaml
    wait_for_db_proxy
    # One replica first: it creates the database tables. Two replicas starting together on an
    # empty database race on those migrations and can both get stuck on the migration lock.
    if ! kubectl -n "${NS}" get deploy backstage >/dev/null 2>&1; then
      apply_manifest backstage.yaml
      wait_for_backstage
    fi
    info "Scaling Backstage to 2 replicas, spread over the zones"
    kubectl -n "${NS}" patch deploy backstage --patch-file "${MORE_DIR}/backstage-ha-patch.yaml" >/dev/null
    kubectl apply -f "${MORE_DIR}/backstage-pdb.yaml" >/dev/null
    wait_for_backstage
    wait_for_catalog
    show_state
    echo
    bold "Portal: $(base_url)"
    ;;
  fail)
    use_cluster
    pg_zone="$(zone_of_pod postgres-0)"
    zone="${2:-}"
    if [[ -z "${zone}" ]]; then
      [[ "${pg_zone}" == "zone-a" ]] && zone="zone-b" || zone="zone-a"
    fi
    echo
    bold "🔥🔥🔥  Availability zone ${zone} just went down  🔥🔥🔥"
    [[ "${zone}" == "${pg_zone}" ]] && warn "Postgres and its disk are in ${zone}."
    echo
    info "Cordoning and draining every node in ${zone}"
    kubectl cordon -l "topology.kubernetes.io/zone=${zone}" >/dev/null
    for node in $(kubectl get nodes -l "topology.kubernetes.io/zone=${zone}" -o name); do
      kubectl drain "${node}" --ignore-daemonsets --delete-emptydir-data --timeout=60s >/dev/null 2>&1 \
        || warn "Draining ${node} did not finish. Something can not move out of ${zone}."
    done
    sleep 5
    show_state
    ;;
  heal)
    use_cluster
    kubectl uncordon -l topology.kubernetes.io/zone >/dev/null
    ok "Every zone is schedulable again"
    show_state
    ;;
  status)
    use_cluster
    show_state
    ;;
  down)
    kind delete cluster --name "${CLUSTER_NAME}"
    kubectl config use-context "kind-backstage-workshop" >/dev/null 2>&1 || true
    ok "Two-zone cluster deleted"
    ;;
  *)
    sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac

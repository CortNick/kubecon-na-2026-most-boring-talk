#!/usr/bin/env bash
# Creates the workshop cluster and starts Postgres and Backstage in it.
# Runs automatically when the Codespace is created or started; safe to run again.
source "$(dirname "$0")/lib.sh"

# If any step fails, say so loudly and leave a marker for 'make ui'.
set -E
rm -f "${SETUP_FAILED_MARKER}"
on_failure() {
  echo "Setup failed at: ${BASH_COMMAND}" >"${SETUP_FAILED_MARKER}"
  echo
  printf '\033[31m✘ The setup FAILED. Fix the error above, then run: make setup\033[0m\n' >&2
}
trap on_failure ERR

start=$(date +%s)

# The tour needs the portal URL, which is only known now.
"${ROOT_DIR}/scripts/render-tour.sh"

if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  ok "Cluster '${CLUSTER_NAME}' already exists"
  # After a Codespace restart the node container may still be stopped.
  docker start "${CLUSTER_NAME}-control-plane" >/dev/null
  prepull_images
else
  info "Creating kind cluster '${CLUSTER_NAME}'"
  # kind runs in the background so the lab images can download while it starts the control plane.
  kind create cluster --name "${CLUSTER_NAME}" --image "${KIND_NODE_IMAGE}" \
    --config "${ROOT_DIR}/scripts/kind-config.yaml" --wait 120s &
  kind_pid=$!
  prepull_while_kind_starts "${kind_pid}"
  wait "${kind_pid}"   # kind's exit code: a failed create still stops the setup
fi
kubectl config use-context "kind-${CLUSTER_NAME}" >/dev/null
require_cluster

info "Starting Postgres and Backstage $(sed -E 's/.*:([^@]+)@.*/\1/' <<<"${BACKSTAGE_IMAGE}")"
apply_lab

echo
ok "All set in $(( $(date +%s) - start ))s. Portal: $(base_url)"
ok "Continue with docs/00-verify-setup.md."

#!/usr/bin/env bash
# Shared helpers for the workshop scripts.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/scripts/versions.env"
export KIND_NODE_IMAGE BACKSTAGE_IMAGE POSTGRES_IMAGE TOXIPROXY_IMAGE NGINX_IMAGE

# The one kind cluster used for the whole workshop, and the namespace Backstage runs in.
CLUSTER_NAME="backstage-workshop"
NS="backstage"

# The scripts always talk to Backstage through the kind port mapping, even in Codespaces.
API="http://localhost:7007"

# Where 'make backup' writes its dumps.
BACKUP_DIR="${ROOT_DIR}/backups"

# Small state files the scripts leave for each other.
STATE_DIR="${HOME}/.backstage-workshop"
SETUP_FAILED_MARKER="${STATE_DIR}/setup-failed"   # written by 'make setup' when it fails
mkdir -p "${STATE_DIR}"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
info()  { printf '\033[36m==>\033[0m %s\n' "$*"; }
ok()    { printf '\033[32m✔\033[0m %s\n' "$*"; }
warn()  { printf '\033[33m!\033[0m %s\n' "$*"; }
fail()  { printf '\033[31m✘\033[0m %s\n' "$*" >&2; exit 1; }

# Every command that touches the cluster is printed before it runs, so attendees see
# what the make targets do. The lines go to fd 3 (the terminal's stderr), so a caller's
# '>/dev/null 2>&1' hides the command's output but never the command itself.
exec 3>&2
show() { printf '\033[35m$\033[0m %s\n' "$*" >&3; }  # show "TEXT": print a command line as is
run() {                                                # run CMD ARGS...: print it, then run it
  local words=() a
  for a in "$@"; do
    if [[ "${a}" =~ ^[A-Za-z0-9_./:=@%+,-]+$ ]]; then words+=("${a}"); else words+=("'${a}'"); fi
  done
  show "${words[*]}"
  "$@"
}
# sh_run "COMMAND LINE": print a command line (pipes, redirects and all), run exactly that line,
# and say so if it printed nothing. Never fails the script: a failing check is part of the lesson.
sh_run() {
  show "$1"
  local out
  out="$(cd "${ROOT_DIR}" && bash -c "$1" 2>&1)" || true
  if [[ -n "${out}" ]]; then printf '%s\n' "${out}"; else echo "(no answer)"; fi
}
# sh_exec "COMMAND LINE": like sh_run, but for steps that must work (backup, restore):
# output is not captured, and a failure anywhere in the pipeline stops the script.
sh_exec() {
  show "$1"
  (cd "${ROOT_DIR}" && bash -o pipefail -c "$1")
}

require_cluster() {
  kubectl cluster-info >/dev/null 2>&1 || fail "No reachable cluster. Run 'make setup' first."
}

# base_url prints the URL your browser uses to reach the portal.
base_url() {
  if [[ -n "${CODESPACE_NAME:-}" && -n "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" ]]; then
    echo "https://${CODESPACE_NAME}-7007.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
  else
    echo "http://localhost:7007"
  fi
}

# apply_manifest applies a file from manifests/, filling in the ${*_IMAGE} pins from versions.env.
apply_manifest() {
  perl -pe 's/\$\{(\w+_IMAGE)\}/$ENV{$1}/g' "${ROOT_DIR}/manifests/$1" | kubectl apply -f - >/dev/null
}

# configmap_from NAME FILE... creates or updates a ConfigMap from plain files.
configmap_from() {
  local name="$1"; shift
  local args=()
  for f in "$@"; do args+=(--from-file="${ROOT_DIR}/manifests/${f}"); done
  kubectl -n "${NS}" create configmap "${name}" "${args[@]}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
}

# apply_config writes every ConfigMap Backstage reads. Restarts Backstage if its URL changed.
apply_config() {
  local url old
  url="$(base_url)"
  old="$(kubectl -n "${NS}" get configmap backstage-base-url -o jsonpath='{.data.BASE_URL}' 2>/dev/null || true)"
  kubectl -n "${NS}" create configmap backstage-base-url --from-literal=BASE_URL="${url}" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
  configmap_from backstage-app-config app-config.lab.yaml
  configmap_from backstage-catalog catalog/all.yaml catalog/template.yaml
  configmap_from catalog-files catalog-files/catalog-info.yaml
  if [[ -n "${old}" && "${old}" != "${url}" ]] && kubectl -n "${NS}" get deploy backstage >/dev/null 2>&1; then
    info "The portal URL changed to ${url}; restarting Backstage"
    kubectl -n "${NS}" rollout restart deploy/backstage >/dev/null
  fi
}

# prepull_backstage starts pulling the Backstage image into the kind node in the background,
# so it downloads while Postgres starts. Its output goes to a log; the kubelet pulls anyway if it fails.
prepull_backstage() {
  docker exec "${CLUSTER_NAME}-control-plane" crictl pull "${BACKSTAGE_IMAGE}" \
    >"${STATE_DIR}/prepull.log" 2>&1 &
}

wait_for_postgres() {
  info "Waiting for Postgres"
  run kubectl -n "${NS}" rollout status statefulset/postgres --timeout=300s >/dev/null
  run kubectl -n "${NS}" wait --for=condition=Ready pod/postgres-0 --timeout=300s >/dev/null
}

wait_for_db_proxy() {
  info "Waiting for the network between Backstage and Postgres (db-proxy)"
  run kubectl -n "${NS}" rollout status deploy/db-proxy --timeout=180s >/dev/null
}

# toxiproxy ARGS... runs toxiproxy-cli inside the db-proxy pod, printing the command.
toxiproxy() {
  run kubectl -n "${NS}" exec deploy/db-proxy -- /toxiproxy-cli "$@"
}

# db_proxy_has_toxics: true while 'make db-slow' or 'make db-unreachable' is still in effect.
db_proxy_has_toxics() {
  kubectl -n "${NS}" exec deploy/db-proxy -- /toxiproxy-cli inspect postgres 2>/dev/null \
    | grep -qE 'slow|unreachable'
}

wait_for_backstage() {
  info "Waiting for Backstage on ${API}"
  run kubectl -n "${NS}" rollout status deploy/backstage --timeout=300s >/dev/null
  show "curl -fsS ${API}/.backstage/health/v1/readiness     # repeated until Backstage answers"
  for _ in $(seq 1 150); do
    curl -fsS -o /dev/null "${API}/.backstage/health/v1/readiness" 2>/dev/null && return 0
    sleep 2
  done
  fail "Backstage is not reachable on localhost:7007. Run 'make status' to see what is wrong."
}

# wait_for_catalog waits until Backstage has read the seed catalog from its config.
wait_for_catalog() {
  for _ in $(seq 1 60); do
    [[ "$(entity_count)" =~ ^[1-9] ]] && return 0
    sleep 1
  done
  warn "The catalog is still empty. It fills in by itself; check again with 'make status'."
}

# fresh_postgres replaces the Postgres disk with a new, empty one and waits for Postgres.
# The StatefulSet is scaled to 0 first: otherwise its new pod can grab the old disk before it is gone.
fresh_postgres() {
  run kubectl -n "${NS}" scale statefulset/postgres --replicas=0
  run kubectl -n "${NS}" wait --for=delete pod/postgres-0 --timeout=120s >/dev/null 2>&1 || true
  run kubectl -n "${NS}" delete pvc data-postgres-0 --ignore-not-found --wait=true
  run kubectl -n "${NS}" scale statefulset/postgres --replicas=1
  wait_for_postgres
}

# apply_lab creates (or updates) everything in the namespace and waits for it.
apply_lab() {
  apply_manifest namespace.yaml
  apply_config
  apply_manifest postgres.yaml
  apply_manifest catalog-files.yaml
  wait_for_postgres
  apply_manifest db-proxy.yaml
  wait_for_db_proxy
  apply_manifest backstage.yaml
  wait_for_backstage
  wait_for_catalog
  kubectl -n "${NS}" rollout status deploy/catalog-files --timeout=120s >/dev/null
}

# guest_token signs in as the guest user and prints a Backstage token.
guest_token() {
  curl -fsS -H 'X-Requested-With: XMLHttpRequest' "${API}/api/auth/guest/refresh" \
    | jq -r '.backstageIdentity.token'
}

# api_get PATH reads the Backstage API. No token needed: the lab disables the default auth policy.
api_get() {
  curl -fsS --max-time 5 "${API}$1"
}

# The three numbers the lab is about. Each prints '?' if the API does not answer.
entity_count()   { api_get '/api/catalog/entities/by-query?limit=1' 2>/dev/null | jq -r '.totalItems' 2>/dev/null || echo '?'; }
task_count()     { api_get '/api/scaffolder/v2/tasks' 2>/dev/null | jq -r '.totalTasks // (.tasks | length)' 2>/dev/null || echo '?'; }
location_count() { api_get '/api/catalog/locations' 2>/dev/null | jq -r '[.[] | select(.data.type == "url")] | length' 2>/dev/null || echo '?'; }

# newest_backup prints the path of the most recent dump, or nothing.
newest_backup() { ls -1 "${BACKUP_DIR}"/*.sql 2>/dev/null | sort | tail -1 || true; }

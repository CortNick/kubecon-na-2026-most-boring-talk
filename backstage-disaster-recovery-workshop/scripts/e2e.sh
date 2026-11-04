#!/usr/bin/env bash
# Maintainer check, not part of the lab: runs the whole lab through the API and asserts
# the lesson holds. Starts with 'make reset', so it wipes whatever you did by hand.
# Usage: scripts/e2e.sh
source "$(dirname "$0")/lib.sh"
require_cluster

declare -a timings=()
phase() {
  local name="$1"; shift
  local s; s=$(date +%s)
  "$@"
  timings+=("$(printf '%-18s %4ss' "${name}" $(( $(date +%s) - s )))")
}
check() { # check DESCRIPTION ACTUAL EXPECTED
  if [[ "$2" == "$3" ]]; then ok "$1: $2"; else fail "$1: got '$2', expected '$3'"; fi
}
# Entities from a new registration or a restart appear a few seconds later.
wait_for_count() { # wait_for_count FUNCTION EXPECTED
  for _ in $(seq 1 60); do [[ "$($1)" == "$2" ]] && return 0; sleep 1; done
}
search_hits() { api_get '/api/search/query?term=checkout' 2>/dev/null | jq '.results | length' 2>/dev/null || echo '?'; }
seed_names() { api_get '/api/catalog/entities?filter=kind=component&fields=metadata.name' | jq -r '[.[].metadata.name] | sort | join(",")'; }

phase reset "${ROOT_DIR}/scripts/reset.sh"
check "Frontend served" "$(curl -fsS "${API}/" | grep -c '<div id="root">')" 1
token="$(guest_token)"
check "Guest sign-in works" "$( [[ "${token}" == eyJ* ]] && echo yes)" yes
check "Seed components" "$(seed_names)" "cart-service,checkout-api,checkout-web"

phase seed "${ROOT_DIR}/scripts/seed.sh"
wait_for_count entity_count 11
tasks_before="$(task_count)"; locations_before="$(location_count)"; entities_before="$(entity_count)"
check "Tasks before" "${tasks_before}" 2
check "Registered locations before" "${locations_before}" 1
check "Entities before" "${entities_before}" 11

phase backup "${ROOT_DIR}/scripts/backup.sh"

# Failures that lose nothing: the Backstage pod, a slow database, an unreachable database.
phase kill-backstage "${ROOT_DIR}/scripts/kill-backstage.sh"
wait_for_count entity_count "${entities_before}"
check "Entities after killing the Backstage pod" "$(entity_count)" "${entities_before}"
check "Tasks after killing the Backstage pod" "$(task_count)" "${tasks_before}"
backstage_pod() { kubectl -n "${NS}" get pods -l app=backstage -o jsonpath='{.items[0].metadata.name}'; }
backstage_ready() { kubectl -n "${NS}" get pods -l app=backstage -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}'; }
# The killed pod can still be Terminating: wait until only its replacement is left.
for _ in $(seq 1 60); do
  [[ "$(kubectl -n "${NS}" get pods -l app=backstage -o name | wc -l | xargs)" == 1 ]] && break
  sleep 1
done
pod_before="$(backstage_pod)"

phase db-slow env LATENCY=1000 "${ROOT_DIR}/scripts/db-slow.sh"
took="$(curl -sf -o /dev/null --max-time 60 -w '%{time_total}' "${API}/api/catalog/entities/by-query?limit=1" || echo 0)"
check "API answers, slowly, with a slow database" "$(awk -v t="${took}" 'BEGIN { print (t >= 1 ? "yes" : "no (" t "s)") }')" yes

phase db-unreachable "${ROOT_DIR}/scripts/db-unreachable.sh"
check "Portal API down with the database unreachable" "$(entity_count)" "?"
check "Backstage pod still Ready with the database unreachable" "$(backstage_ready)" True

phase db-heal "${ROOT_DIR}/scripts/db-heal.sh"
wait_for_count entity_count "${entities_before}"
check "Entities after healing the network" "$(entity_count)" "${entities_before}"
check "Tasks after healing the network" "$(task_count)" "${tasks_before}"
check "Backstage was not restarted to recover" "$(backstage_pod)" "${pod_before}"

phase disaster "${ROOT_DIR}/scripts/disaster.sh"
check "Portal API down after disaster" "$(entity_count)" "?"

phase restart-backend "${ROOT_DIR}/scripts/restart-backend.sh"
wait_for_count entity_count 9
check "Seed entities back after empty restart" "$(entity_count)" 9
check "Seed components back" "$(seed_names)" "cart-service,checkout-api,checkout-web"
check "Tasks after empty restart" "$(task_count)" 0
check "Registered locations after empty restart" "$(location_count)" 0
s=$(date +%s); for _ in $(seq 1 120); do [[ "$(search_hits)" =~ ^[1-9] ]] && break; sleep 1; done
check "Search index rebuilt by itself" "$( [[ "$(search_hits)" =~ ^[1-9] ]] && echo yes)" yes
timings+=("$(printf '%-18s %4ss' "search rebuilt" $(( $(date +%s) - s )))")

phase restore "${ROOT_DIR}/scripts/restore.sh"
wait_for_count entity_count "${entities_before}"
check "Tasks after restore" "$(task_count)" "${tasks_before}"
check "Registered locations after restore" "$(location_count)" "${locations_before}"
check "Entities after restore" "$(entity_count)" "${entities_before}"

echo
bold "All checks passed. Timings:"
printf '  %s\n' "${timings[@]}"

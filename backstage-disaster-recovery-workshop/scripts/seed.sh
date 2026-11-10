#!/usr/bin/env bash
# Facilitator shortcut for Part 1: runs the template twice and registers legacy-billing,
# through the API instead of the portal.
source "$(dirname "$0")/lib.sh"
require_cluster

token="$(guest_token)"
for name in seed-one seed-two; do
  id="$(curl -fsS -X POST "${API}/api/scaffolder/v2/tasks" \
    -H "Authorization: Bearer ${token}" -H 'Content-Type: application/json' \
    -d "{\"templateRef\":\"template:default/create-lab-service\",\"values\":{\"serviceName\":\"${name}\"}}" | jq -r .id)"
  ok "Ran the template for ${name} (task ${id})"
done
"${ROOT_DIR}/scripts/register.sh"

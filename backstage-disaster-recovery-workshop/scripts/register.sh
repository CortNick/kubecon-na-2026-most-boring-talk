#!/usr/bin/env bash
# Registers legacy-billing through the catalog API: the same call the portal's
# "Register existing component" page makes.
source "$(dirname "$0")/lib.sh"
require_cluster

TARGET="http://legacy-billing.backstage.svc.cluster.local/catalog-info.yaml"
token="$(guest_token)"
code="$(curl -sS -o /dev/null -w '%{http_code}' -X POST "${API}/api/catalog/locations" \
  -H "Authorization: Bearer ${token}" -H 'Content-Type: application/json' \
  -d "{\"type\":\"url\",\"target\":\"${TARGET}\"}")"
case "${code}" in
  201) ok "Registered ${TARGET}" ;;
  409) ok "Already registered: ${TARGET}" ;;
  *)   fail "Registering failed with HTTP ${code}. Run 'make status'." ;;
esac

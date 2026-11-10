#!/usr/bin/env bash
# Checks that Backstage is ready and prints the portal address.
source "$(dirname "$0")/lib.sh"

if pgrep -f "scripts/setup.sh" >/dev/null; then
  warn "The setup is still running. Wait for it to finish, then run 'make ui' again."
  warn "To watch it: Command Palette > 'Codespaces: View Creation Log'."
  exit 1
fi
if [[ -f "${SETUP_FAILED_MARKER}" ]]; then
  fail "The setup failed ($(cat "${SETUP_FAILED_MARKER}")). Run 'make setup' to try again."
fi
require_cluster
kubectl -n "${NS}" get deploy backstage >/dev/null 2>&1 || fail "Backstage is not installed. Run 'make setup'."
wait_for_backstage

url="$(base_url)"
configured="$(kubectl -n "${NS}" get configmap backstage-base-url -o jsonpath='{.data.BASE_URL}')"
ok "Backstage is ready"
echo
bold "Portal: ${url}"
echo  "Sign in: select ENTER under 'Guest'."
if [[ "${configured}" == "${url}" ]]; then
  ok "Check: Backstage is configured for this same URL, so the API calls from your browser will work."
else
  warn "Check FAILED: Backstage is configured for ${configured}. Run 'make setup' to fix it."
fi

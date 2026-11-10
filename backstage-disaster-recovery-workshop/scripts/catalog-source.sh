#!/usr/bin/env bash
# Shows where the seed catalog comes from, and why it survives losing the database.
source "$(dirname "$0")/lib.sh"
require_cluster

bold "# 1. Backstage's config lists two catalog files to read on every start"
sh_run "kubectl -n ${NS} exec deploy/backstage -- grep -A6 '^catalog:' /config/app-config.lab.yaml"
echo
bold "# 2. Those files are a ConfigMap, mounted into the pod at /catalog"
sh_run "kubectl -n ${NS} get configmap backstage-catalog"
sh_run "kubectl -n ${NS} exec deploy/backstage -- ls /catalog"
echo
bold "# 3. The components in it: the three that came back"
sh_run "kubectl -n ${NS} exec deploy/backstage -- grep -A1 '^kind: Component' /catalog/all.yaml"
echo
ok "In Git (manifests/catalog/all.yaml) → ConfigMap → read by Backstage on every start."
warn "legacy-billing is not in any file: it was registered in the portal, so it lived only in Postgres."

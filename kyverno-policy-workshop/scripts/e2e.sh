#!/usr/bin/env bash
# End-to-end proof that every scenario breaks and every documented fix works.
# Runs in CI on a fresh kind cluster. Also handy before the dry run.
set -euo pipefail
trap 'echo "::error::e2e.sh failed at line $LINENO: $BASH_COMMAND"' ERR
cd "$(dirname "$0")/.."
step() { printf '\n\033[1;35m=== %s ===\033[0m\n' "$*"; }
must_fail() { if "$@"; then echo "::error::EXPECTED FAILURE but passed: $*"; exit 1; fi; }
t() { local s=$SECONDS; "$@"; echo "⏱  $(( SECONDS - s ))s: $*"; }

step "Setup is safe to re-run on an existing lab cluster"
t ./lab.sh setup > /tmp/setup2.txt; tail -3 /tmp/setup2.txt
./lab.sh status > /tmp/st.txt; grep -q "Cluster: kind-kyverno-lab" /tmp/st.txt

step "Guard: lab.sh refuses any cluster that isn't the lab's"
kubectl config set-context not-the-lab --cluster=kind-kyverno-lab --user=kind-kyverno-lab >/dev/null
kubectl config use-context not-the-lab >/dev/null
must_fail ./lab.sh status
must_fail ./lab.sh break 2
out=$(./lab.sh status 2>&1) || true
echo "$out"; echo "$out" | grep -q "not the lab cluster"
kubectl config use-context kind-kyverno-lab >/dev/null
kubectl config delete-context not-the-lab >/dev/null

step "Missing Kyverno CLI: clear message, no crash"
must_fail env PATH=/usr/bin:/bin ./lab.sh ci manifests/scenario-3/disallow-privileged.yaml
out=$(env PATH=/usr/bin:/bin ./lab.sh ci manifests/scenario-3/disallow-privileged.yaml 2>&1) || true
echo "$out"; echo "$out" | grep -q "'kyverno' is not installed"

step "Scenario 1: break"
t ./lab.sh break 1
sleep 15
must_fail ./lab.sh check 1
kubectl -n shop get events --field-selector reason=FailedCreate -o custom-columns=FROM:.source.component,MESSAGE:.message | tail -2 | tee /tmp/ev.txt
grep -q "replicaset-controller" /tmp/ev.txt && grep -q "team' label" /tmp/ev.txt
step "Scenario 1: challenge hint (CLI against the app manifest) must report failures"
(kyverno apply manifests/scenario-1/require-team-label.yaml --resource manifests/app/shop.yaml || true) | tee /tmp/c1.txt
grep -E "fail: [1-9]" /tmp/c1.txt
step "Scenario 1: fix (label the app)"
kubectl -n shop patch deploy shop --type merge \
  -p '{"spec":{"template":{"metadata":{"labels":{"team":"payments"}}}}}'
kubectl -n shop rollout status deploy/shop --timeout=120s
./lab.sh check 1

step "Scenario 1: alt fix (Audit mode)"
./lab.sh break 1; sleep 10
kubectl apply -f solutions/scenario-1-require-team-label-audit.yaml
for i in $(seq 1 24); do ./lab.sh check 1 && break; sleep 5; done
./lab.sh check 1

step "Scenario 2: break"
t ./lab.sh break 2
must_fail kubectl -n shop rollout restart deploy/shop
kubectl -n kyverno get pods
kubectl -n kyverno get endpointslices -l kubernetes.io/service-name=kyverno-svc
kubectl -n kyverno get svc kyverno-svc -o jsonpath='{.spec.selector}{"\n"}'
kubectl -n kyverno get pods -l app.kubernetes.io/part-of=kyverno -L app.kubernetes.io/component
kubectl get validatingwebhookconfigurations -o jsonpath='{range .items[*].webhooks[*]}{.name}{"  failurePolicy="}{.failurePolicy}{"\n"}{end}'
must_fail ./lab.sh check 2
sleep 30
must_fail kubectl -n shop rollout restart deploy/shop   # outage must persist (lab timing)
step "Scenario 2: fix"
kubectl -n kyverno patch svc kyverno-svc --type merge \
  -p '{"spec":{"selector":{"app.kubernetes.io/component":"admission-controller"}}}'
for i in $(seq 1 12); do ./lab.sh check 2 && break; sleep 5; done
./lab.sh check 2
kubectl -n shop rollout restart deploy/shop

step "Scenario 3: break"
t ./lab.sh break 3
kubectl -n shop get pod debug-tools
kubectl get validatingpolicy disallow-privileged -o jsonpath='{.spec.matchConstraints.namespaceSelector}{"\n"}' | tee /tmp/sel.txt
grep -q '"env":"production"' /tmp/sel.txt
kubectl get ns shop --show-labels | grep -q "environment=production"
must_fail ./lab.sh check 3
kyverno apply manifests/scenario-3/disallow-privileged.yaml \
  --resource manifests/scenario-3/debug-pod.yaml --values-file manifests/scenario-3/values.yaml
step "Scenario 3: fix"
kubectl apply -f solutions/scenario-3-disallow-privileged.yaml
sleep 5
must_fail ./lab.sh check 3          # pod still running -> still failing
kubectl -n shop delete pod debug-tools
./lab.sh check 3
must_fail kubectl apply -f manifests/scenario-3/debug-pod.yaml

step "Order independence: 3 -> 1 -> 2 -> reset"
./lab.sh break 3 >/dev/null; ./lab.sh break 1 >/dev/null; ./lab.sh break 2 >/dev/null; ./lab.sh reset
kubectl -n shop get deploy shop

step "Last step: catch it before production (offline CI gates)"
must_fail kyverno apply manifests/scenario-1/require-team-label.yaml --resource manifests/app/shop.yaml
must_fail ./lab.sh ci manifests/scenario-3/disallow-privileged.yaml
./lab.sh ci solutions/scenario-3-disallow-privileged.yaml

step "Offline: kyverno test suite in more/ (fixed policy)"
kyverno test more/tests

echo; echo "ALL SCENARIOS VERIFIED ✅"

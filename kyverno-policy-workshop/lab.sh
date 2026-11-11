#!/usr/bin/env bash
# Kyverno "what breaks" lab driver.
#   ./lab.sh setup        check your tools, create the lab's own kind cluster, install Kyverno, deploy the shop app
#   ./lab.sh break N      break the platform (N = 1, 2 or 3). Each scenario is standalone.
#   ./lab.sh check N      did you fix it?
#   ./lab.sh reset        put everything back to healthy
#   ./lab.sh status       quick health view
#   ./lab.sh ci POLICY    the CI gate: does POLICY deny a known-bad pod? (offline, needs the Kyverno CLI)
#   ./lab.sh cleanup      delete the lab's kind cluster (and nothing else)
#
# Safety: this script only ever talks to the lab's own cluster (kubectl context
# "kind-kyverno-lab"). It refuses to run against any other cluster.
set -uo pipefail

KYVERNO_VERSION="${KYVERNO_VERSION:-v1.19.1}"
CLUSTER_NAME="${CLUSTER_NAME:-kyverno-lab}"
LAB_CONTEXT_DEFAULT="kind-${CLUSTER_NAME}"
# Advanced, opt-in: run against a DISPOSABLE cluster of your own instead of kind.
# Scenario 2 deliberately breaks Kyverno on that cluster. Never point this at a shared cluster.
LAB_CONTEXT="${LAB_CONTEXT:-$LAB_CONTEXT_DEFAULT}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
M="$HERE/manifests"
AC="kyverno-admission-controller"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
ok()    { printf '\033[32m✅ %s\033[0m\n' "$*"; }
fail()  { printf '\033[31m❌ %s\033[0m\n' "$*"; }
info()  { printf '\033[36m👉 %s\033[0m\n' "$*"; }
story() { printf '\n\033[33m%s\033[0m\n\n' "$*"; }
warn()  { printf '\033[33m⚠️  %s\033[0m\n' "$*"; }

# How to install a missing tool, for the computer this is running on.
install_hint() {
  local tool="$1"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    case "$tool" in
      docker)  echo "Install and start Docker Desktop: https://docs.docker.com/desktop/setup/install/mac-install/" ;;
      *)       echo "brew install $tool" ;;
    esac
  else
    case "$tool" in
      docker)  echo "Install Docker: https://docs.docker.com/engine/install/ (on Windows: Docker Desktop + WSL2, and run this lab inside WSL)" ;;
      kind)    echo "https://kind.sigs.k8s.io/docs/user/quick-start/#installation" ;;
      kubectl) echo "https://kubernetes.io/docs/tasks/tools/#kubectl" ;;
      kyverno) echo "https://kyverno.io/docs/kyverno-cli/install/  (or: brew install kyverno)" ;;
    esac
  fi
}

need() {  # need <tool> <why>
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "'$1' is not installed. It's needed $2."
    info "$(install_hint "$1")"
    return 1
  fi
}

current_context() { kubectl config current-context 2>/dev/null || echo "(none)"; }

# Every command that touches a cluster calls this first.
require_lab_cluster() {
  need kubectl "to talk to the lab cluster" || exit 1
  local ctx; ctx="$(current_context)"
  if [[ "$ctx" != "$LAB_CONTEXT" ]]; then
    fail "kubectl is pointing at '$ctx', not the lab cluster '$LAB_CONTEXT'."
    info "This lab breaks Kyverno on purpose, so it refuses to run on any other cluster."
    if kubectl config get-contexts -o name 2>/dev/null | grep -qx "$LAB_CONTEXT"; then
      info "Switch to the lab cluster:  kubectl config use-context $LAB_CONTEXT"
    else
      info "Create the lab cluster first:  ./lab.sh setup"
    fi
    exit 1
  fi
  if ! kubectl cluster-info >/dev/null 2>&1; then
    fail "Can't reach the lab cluster '$LAB_CONTEXT'."
    info "Is Docker running? Start it, then run:  ./lab.sh setup"
    exit 1
  fi
}

wait_policy_ready() {
  kubectl wait "validatingpolicy/$1" \
    --for=jsonpath='{.status.conditionStatus.ready}'=true --timeout=90s >/dev/null 2>&1 \
    || info "Policy $1 is taking a while to report READY; carrying on."
  sleep 3   # give Kyverno a moment to register its webhook rules
}

setup() {
  bold "Checking your tools..."
  local ok_tools=1
  need kubectl "to talk to the cluster" || ok_tools=0
  if [[ "$LAB_CONTEXT" == "$LAB_CONTEXT_DEFAULT" ]]; then
    need docker "to run the lab's kind cluster" || ok_tools=0
    need kind "to create the lab's local cluster" || ok_tools=0
  fi
  [[ $ok_tools == 1 ]] || { info "Install what's missing, then run ./lab.sh setup again. (Or use GitHub Codespaces: nothing to install.)"; return 1; }
  if ! command -v kyverno >/dev/null 2>&1; then
    warn "The Kyverno CLI ('kyverno') is not installed. Scenarios 1 and 2 work without it."
    info "You'll need it for the offline checks in Scenario 3 and the Last step: $(install_hint kyverno)"
  fi

  if [[ "$LAB_CONTEXT" == "$LAB_CONTEXT_DEFAULT" ]]; then
    if ! docker info >/dev/null 2>&1; then
      bold "Waiting for Docker to start (up to 60 seconds)..."
      local w; for w in $(seq 1 30); do docker info >/dev/null 2>&1 && break; sleep 2; done
    fi
    if ! docker info >/dev/null 2>&1; then
      fail "Docker is installed but not running."
      info "Start Docker (Docker Desktop on Mac/Windows), wait until it says it's running, then run ./lab.sh setup again."
      return 1
    fi
    if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
      bold "Found the lab cluster '$CLUSTER_NAME'."
      docker start "${CLUSTER_NAME}-control-plane" >/dev/null 2>&1 || true
      kind export kubeconfig --name "$CLUSTER_NAME" >/dev/null 2>&1
      local i; for i in $(seq 1 30); do kubectl --context "$LAB_CONTEXT" get --raw=/readyz >/dev/null 2>&1 && break; sleep 2; done
      if ! kubectl --context "$LAB_CONTEXT" get --raw=/readyz >/dev/null 2>&1; then
        warn "The lab cluster didn't come back after a restart. Re-creating it (about 2 minutes)..."
        kind delete cluster --name "$CLUSTER_NAME" >/dev/null 2>&1
        kind create cluster --name "$CLUSTER_NAME" --wait 120s || { fail "kind couldn't create the cluster."; return 1; }
      fi
    else
      bold "Creating the lab's own kind cluster '$CLUSTER_NAME' (about 1 minute)..."
      kind create cluster --name "$CLUSTER_NAME" --wait 120s || { fail "kind couldn't create the cluster. See the error above."; return 1; }
    fi
    kubectl config use-context "$LAB_CONTEXT" >/dev/null
    info "kubectl now points at the lab cluster ($LAB_CONTEXT). Your other clusters are untouched."
  else
    warn "LAB_CONTEXT is set: using YOUR cluster '$LAB_CONTEXT' instead of a kind cluster."
    warn "Scenario 2 breaks Kyverno on it on purpose. Only do this on a disposable cluster."
    kubectl config use-context "$LAB_CONTEXT" >/dev/null || { fail "No kubectl context called '$LAB_CONTEXT'."; return 1; }
  fi
  require_lab_cluster

  if kubectl get deploy -n kyverno "$AC" >/dev/null 2>&1; then
    local img; img=$(kubectl -n kyverno get deploy "$AC" -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
    if [[ "$img" != *":$KYVERNO_VERSION" ]]; then
      warn "This cluster already runs a different Kyverno ($img). The lab is written for $KYVERNO_VERSION; outputs may differ."
    fi
  else
    bold "Installing Kyverno $KYVERNO_VERSION..."
    kubectl apply --server-side \
      -f "https://github.com/kyverno/kyverno/releases/download/${KYVERNO_VERSION}/install.yaml" >/dev/null
  fi
  bold "Waiting for Kyverno..."
  for d in admission background cleanup reports; do
    kubectl -n kyverno rollout status "deploy/kyverno-${d}-controller" --timeout=300s
  done
  reset
  ok "Lab ready. Start with:  ./lab.sh break 1   (or 2, or 3 — any order)"
}

cleanup() {
  if [[ "$LAB_CONTEXT" != "$LAB_CONTEXT_DEFAULT" ]]; then
    fail "cleanup only deletes the lab's own kind cluster. On your own cluster, remove the lab by hand:"
    info "kubectl delete ns shop; kubectl delete validatingpolicy require-team-label disallow-latest-tag disallow-privileged --ignore-not-found"
    return 1
  fi
  need kind "to delete the lab cluster" || return 1
  if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
    kind delete cluster --name "$CLUSTER_NAME"
    ok "Deleted the lab cluster '$CLUSTER_NAME'. Nothing else was touched."
    info "Your kubectl context is now: $(current_context). Check it before running other kubectl commands."
  else
    ok "No lab cluster to delete."
  fi
}

reset() {
  bold "Resetting to a healthy state..."
  kubectl delete validatingpolicy require-team-label disallow-latest-tag disallow-privileged \
    --ignore-not-found >/dev/null 2>&1
  kubectl -n kyverno patch svc kyverno-svc --type merge \
    -p '{"spec":{"selector":{"app.kubernetes.io/component":"admission-controller"}}}' >/dev/null 2>&1
  kubectl -n kyverno scale deploy "$AC" --replicas=1 >/dev/null 2>&1
  kubectl -n kyverno rollout status "deploy/$AC" --timeout=180s >/dev/null 2>&1
  kubectl -n shop delete pod debug-tools debug-tools-2 --ignore-not-found --wait=false >/dev/null 2>&1
  kubectl -n shop delete deploy shop --ignore-not-found >/dev/null 2>&1
  kubectl label ns shop env- >/dev/null 2>&1
  kubectl apply -f "$M/app/shop.yaml" >/dev/null
  kubectl -n shop rollout status deploy/shop --timeout=180s >/dev/null 2>&1
  ok "Healthy: Kyverno up, no lab policies, shop running 2/2."
}

break_1() {
  reset
  kubectl apply -f "$M/scenario-1/require-team-label.yaml" >/dev/null
  wait_policy_ready require-team-label
  # Simulate a node going away: the shop pods get evicted and must be recreated.
  kubectl -n shop delete pod -l app=shop --wait=false >/dev/null
  story "SCENARIO 1 — The rollout that never rolls
Friday 16:55: the platform team shipped a new 'require-team-label' policy. CI was green.
Monday 03:12: a node was recycled. The shop pods were evicted... and never came back.
Nobody touched the shop app. 'kubectl apply' would still say 'configured'.

Your job: find out why the shop has 0 pods, and get it back to 2/2
WITHOUT deleting the policy. Then run:  ./lab.sh check 1"
}

break_2() {
  reset
  kubectl apply -f "$M/scenario-2/disallow-latest-tag.yaml" >/dev/null
  wait_policy_ready disallow-latest-tag
  # A "label standardisation" change re-points Kyverno's Service at a label no pod has.
  # Kyverno's pods keep running, so its webhooks stay registered... and unreachable.
  kubectl -n kyverno patch svc kyverno-svc --type merge \
    -p '{"spec":{"selector":{"app.kubernetes.io/component":"kyverno-admission-controller"}}}' >/dev/null
  sleep 3
  story "SCENARIO 2 — Kyverno is down, so is your platform
Friday's 'label standardisation' PR touched a lot of YAML. It merged green.
Now the deploy pipeline is red for every team. Argo CD shows 'sync failed' everywhere.
Try it yourself:   kubectl -n shop rollout restart deploy/shop

Your job: find out what's blocking ALL changes and restore service.
Then run:  ./lab.sh check 2"
}

break_3() {
  reset
  kubectl apply -f "$M/scenario-3/disallow-privileged.yaml" >/dev/null
  wait_policy_ready disallow-privileged
  kubectl apply -f "$M/scenario-3/debug-pod.yaml" >/dev/null
  story "SCENARIO 3 — The guardrail that guards nothing
Security's rule: no privileged containers in production. The policy is installed,
READY says True, it passed code review.
The pentest report just landed: there's a privileged pod running in 'shop' (production).

Your job: find out why the policy let it in, fix the POLICY, and remove the pod.
Then run:  ./lab.sh check 3"
}

check_1() {
  if ! kubectl get validatingpolicy require-team-label >/dev/null 2>&1; then
    fail "The policy is gone. That 'fixes' it, but now nothing enforces ownership."
    info "Run ./lab.sh break 1 and try fixing the app (or the rollout mode) instead."; return 1
  fi
  local ready; ready=$(kubectl -n shop get deploy shop -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  if [[ "${ready:-0}" == "2" ]]; then
    ok "shop is 2/2 and the policy is still installed. Nice."
    local mode; mode=$(kubectl get validatingpolicy require-team-label -o jsonpath='{.spec.validationActions}')
    info "Policy mode is now $mode. Deny + labelled app = fixed for good. Audit = safer rollout, but nothing is enforced yet."
  else
    fail "shop has ${ready:-0}/2 ready pods. Keep digging."
    info "Hint: no pods means no pod logs. Who CREATES pods? Look at its events."; return 1
  fi
}

check_2() {
  local eps; eps=$(kubectl -n kyverno get endpointslices -l kubernetes.io/service-name=kyverno-svc \
    -o jsonpath='{.items[*].endpoints[*].addresses[*]}' 2>/dev/null)
  if [[ -z "$eps" ]]; then
    fail "kyverno-svc has no endpoints: the API server can't reach Kyverno."
    info "Hint: the pods are Running. Compare the Service's selector with the pods' labels."; return 1
  fi
  if kubectl -n shop run admission-probe --image=nginx:1.27-alpine --labels=team=platform \
       --dry-run=server >/dev/null 2>&1; then
    ok "Admission is answering again. Changes flow."
    info "Production tip: 3 replicas, a PDB, and an alert on webhook errors. See more/README.md."
    return 0
  fi
  fail "Kyverno is reachable, but changes to 'shop' are still rejected. Give it 10s and re-check."; return 1
}

check_3() {
  local probe; probe=$(sed 's/name: debug-tools/name: debug-tools-2/' "$M/scenario-3/debug-pod.yaml")
  if echo "$probe" | kubectl apply --dry-run=server -f - >/dev/null 2>&1; then
    fail "A new privileged pod would STILL be admitted into 'shop'."
    info "Hint: compare the policy's namespaceSelector with: kubectl get ns shop --show-labels"; return 1
  fi
  ok "New privileged pods in production are now denied."
  if kubectl -n shop get pod debug-tools >/dev/null 2>&1; then
    fail "...but debug-tools is still running. Admission policies don't evict what's already there."
    info "Delete it:  kubectl -n shop delete pod debug-tools"; return 1
  fi
  ok "And the existing privileged pod is gone. Guardrail restored."
}

ci() {
  # A CI gate for the "disallow privileged" policy: run it OFFLINE against a pod
  # we KNOW is bad, in a namespace labelled like production. If it doesn't fail
  # that pod, the policy is broken, whatever "READY" says. Same check works in any CI.
  local policy="${1:-}"
  need kyverno "for the offline CI gate (it runs the policy without a cluster)" || return 1
  if [[ -z "$policy" || ! -f "$policy" ]]; then
    echo "usage: $0 ci <policy.yaml>   e.g. $0 ci manifests/scenario-3/disallow-privileged.yaml"; return 1
  fi
  bold "CI gate: does '$policy' deny the known-bad privileged pod?"
  local out; out=$(kyverno apply "$policy" --resource "$M/scenario-3/debug-pod.yaml" \
    --values-file "$M/scenario-3/values.yaml" 2>&1)
  echo "$out" | grep -E '^pass:' || echo "$out" | tail -3
  local fails; fails=$(echo "$out" | grep -oE 'fail: [0-9]+' | grep -oE '[0-9]+' | head -1)
  if [[ "${fails:-0}" -ge 1 ]]; then
    ok "CI passes: the policy denies the known-bad pod. Safe to merge."
  else
    fail "CI blocks this merge: the policy never flagged the known-bad pod (fail: 0)."
    info "A policy that matches nothing looks READY in the cluster. This is how you catch it before it ships."
    return 1
  fi
}

status() {
  info "Cluster: $(current_context)"
  kubectl -n kyverno get deploy
  echo; kubectl get validatingpolicy 2>/dev/null || true
  echo; kubectl -n shop get deploy,pods
}

case "${1:-}" in
  setup)   setup ;;
  reset)   require_lab_cluster; reset ;;
  status)  require_lab_cluster; status ;;
  ci)      ci "${2:-}" ;;
  cleanup) cleanup ;;
  break|check)
    if [[ ! "${2:-}" =~ ^[123]$ ]]; then echo "usage: $0 $1 1|2|3"; exit 1; fi
    require_lab_cluster
    "${1}_$2" ;;
  *) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac

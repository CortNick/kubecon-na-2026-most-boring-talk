# More: running Kyverno like it's part of the control plane

For people who finished early, and for everyone reading this after KubeCon.

## 1. Define the blast radius before you need it

Kyverno is a dependency of every write to the cluster. Write down, per cluster:

| Question | Example answer |
|---|---|
| What stops working if Kyverno is down? | All CREATE/UPDATE on matched kinds in non-excluded namespaces |
| RTO for the admission controller | 5 min (it's stateless — restart is the recovery) |
| RPO for policies | 0 — policies live in Git and sync via Argo CD |
| Who can run break-glass? | Platform on-call, logged in the incident channel |

## 2. High availability (Helm values)

```yaml
admissionController:
  replicas: 3
  podDisruptionBudget:
    enabled: true
    minAvailable: 1
  topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app.kubernetes.io/component: admission-controller
```

Also mirror the Kyverno images into your own registry. If `reg.kyverno.io`
is unreachable during a node replacement, Kyverno can't come back — and
neither can anything it gates.

### Failure modes worth knowing (Kyverno 1.19)

- **Clean shutdown** (scale to 0, uninstall): Kyverno removes its resource webhooks → cluster fails **open**.
- **Unreachable while "up"** (broken Service, NetworkPolicy, expired cert, node lost without cleanup): webhooks stay registered → cluster fails **closed** for every `Fail` policy.
- Watch what the API server sees, not pod status.

## 3. `Fail` or `Ignore`? Decide per policy

| Policy type | failurePolicy | Why |
|---|---|---|
| Security boundary (privileged, host namespaces, image signatures) | `Fail` | Letting it through is worse than blocking a deploy |
| Hygiene (labels, resource limits, best practices) | `Ignore` | An outage is worse than one unlabelled pod |
| New / unproven policy | `Audit` + `Ignore` | Learn first, enforce later |

## 4. Alerts worth having

- Admission controller ready replicas < 2
- Webhook errors / latency from the API server:
  `apiserver_admission_webhook_rejection_count`, `apiserver_admission_webhook_admission_duration_seconds`
- Kyverno's own metrics: `kyverno_admission_requests_total`,
  `kyverno_admission_review_duration_seconds`, `kyverno_policy_results_total`
- **A policy with zero results for 24h** — that's Scenario 3 waiting to happen

## 5. Break-glass runbook (Kyverno can't come back)

Only if restarting the admission controller doesn't work:

```bash
# 1. Announce it in the incident channel. You are turning OFF policy enforcement.
# 2. Remove Kyverno's resource webhooks so the cluster accepts changes again:
kubectl get validatingwebhookconfigurations,mutatingwebhookconfigurations -l webhook.kyverno.io/managed-by=kyverno
kubectl delete validatingwebhookconfigurations,mutatingwebhookconfigurations -l webhook.kyverno.io/managed-by=kyverno
# 3. Fix Kyverno. When the admission controller is healthy it re-creates its webhooks.
# 4. Review what was admitted during the gap:  kubectl get policyreports -A
```

> Verify the label selector on your Kyverno version before you need it:
> `kubectl get validatingwebhookconfigurations --show-labels`

## 6. Catch broken policies in CI

**Rule: every policy must deny at least one known-bad resource in CI.** A policy
that matches nothing still says READY in the cluster (Scenario 3).

```bash
# Fails the build if the policy does NOT flag the known-bad pod.
# (kyverno apply exits 1 when it finds a failure, which here is the GOOD case: hence || true)
out=$(kyverno apply policies/disallow-privileged.yaml \
        --resource tests/known-bad/privileged-pod.yaml \
        --values-file tests/namespaces.yaml) || true
echo "$out"
echo "$out" | grep -qE 'fail: [1-9]' || { echo "Policy matched nothing"; exit 1; }
```

As a GitHub Actions workflow:

```yaml
# .github/workflows/policy-ci.yaml
on: [pull_request]
jobs:
  policy-ci:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          curl -sL https://github.com/kyverno/kyverno/releases/download/v1.19.1/kyverno-cli_v1.19.1_linux_x86_64.tar.gz | tar xz kyverno
          # 1. Would a new policy break workloads that already exist? (exits 1 if so)
          ./kyverno apply policies/ --resource manifests/
          # 2. Does each policy deny its known-bad resource?
          out=$(./kyverno apply policies/disallow-privileged.yaml \
                  --resource tests/known-bad/privileged-pod.yaml \
                  --values-file tests/namespaces.yaml) || true
          echo "$out"; echo "$out" | grep -qE 'fail: [1-9]'
```

**About `kyverno test`.** [`tests/`](tests) has a `kyverno test` suite for the
fixed policy (`kyverno test more/tests`). It's useful for checking pass/fail
results, but note: in Kyverno 1.19 a resource the policy never matched is
reported as **Excluded → Pass**. Run the *broken* Scenario 3 policy through it
and the suite stays green. Keep the "known-bad must fail" check above as well.

## 7. Roll out new policies safely

1. Merge in `validationActions: [Audit]`
2. Watch `kubectl get policyreports -A` for a week
3. Fix or exempt (PolicyException) what fails
4. Switch to `[Deny]`

# Challenge mode 🧗

Same three outages, no walkthrough. You get the symptom, a constraint, and a
"prove it" task. `./lab.sh check N` still tells you when service is restored.
Stuck? The full walkthrough is in [`README.md`](README.md).

Rules for every scenario:
- ❌ Don't delete the policy, uninstall Kyverno, or remove its webhooks.
- ❌ Don't read `manifests/` or `solutions/` until you've written down your diagnosis.
- ✅ Anything else goes.

---

## 1 · The rollout that never rolls

```bash
./lab.sh break 1
```

**Symptom:** `shop` is at 0/2 after a node recycle. Nobody changed it.

**Your goals:**
1. Find the exact error message, and say *which component* received it.
2. Restore `shop` to 2/2 with the policy still in `Deny` mode.
3. **Prove it:** before the policy was enforced, how could you have known
   which workloads it would break? Show the command and its output.
   *(Tip: the Kyverno CLI can test a policy against your app's manifests
   before either one ships, and Audit mode writes PolicyReports.)*

---

## 2 · Kyverno is down, so is your platform

```bash
./lab.sh break 2
```

**Symptom:** every change to pods and Deployments outside `kyverno` and
`kube-system` fails.

**Your goals:**
1. Explain why `kubectl -n kyverno get pods` looks healthy.
2. Restore service with a change confined to the `kyverno` namespace.
3. **Prove it:** list every webhook that would deny requests while Kyverno is
   unreachable, and name the one field that decides it.
4. **Bonus:** write the alert (in words or PromQL) that would have paged you
   within 2 minutes, without relying on pod status.

---

## 3 · The guardrail that guards nothing

```bash
./lab.sh break 3
```

**Symptom:** a privileged pod is running in the production namespace `shop`.
The policy reports READY.

**Your goals:**
1. Prove, **without the cluster**, that the policy never evaluates the pod.
2. Fix it so that new privileged pods in `shop` are denied, and clean up.
3. **Prove it:** write a CI check that **fails** against the broken policy and
   **passes** against your fix, without a cluster. Then explain why a plain
   `kyverno test` suite with `result: fail` for the bad pod is *not* enough on
   its own. *(Try it with [`more/tests`](more/tests) and the broken policy.)*

---

## Debrief questions

- Which of the three would your current monitoring catch? In how long?
- Which of your policies are `Fail` today? Which ones *should* be?
- Who in your org can run break-glass on the policy engine at 3 a.m.?

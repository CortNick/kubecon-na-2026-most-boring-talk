# Helper cheat sheet — Kyverno lab

**Universal fix:** `cd /workspaces/*/kyverno-policy-workshop && ./lab.sh reset`, then `./lab.sh break N` again.
**Health view:** `./lab.sh status`

## The 5 most likely mistakes

| # | What you'll see | Cause | Fix |
|---|---|---|---|
| 1 | `./lab.sh: No such file or directory` | Wrong folder | `cd /workspaces/*/kyverno-policy-workshop` |
| 2 | `The connection to the server ... was refused` / no Kyverno pods | Codespace still booting, or setup failed | `./lab.sh setup` (~2 min). Log: `/tmp/lab-setup.log` |
| 3 | Scenario 1: `check 1` says "policy is gone" | They deleted the policy to make it work | That's the anti-pattern the lab teaches. `./lab.sh break 1`, patch the app instead |
| 4 | Scenario 1: patched the app, still 0/2 | Ran the patch before `break 1` finished, or typo in the JSON | Re-run the patch command from the README exactly; `kubectl -n shop rollout status deploy/shop` |
| 5 | Scenario 3: `check 3` still ❌ after fixing the policy | Privileged pod already running — admission doesn't evict | `kubectl -n shop delete pod debug-tools` |

## Also common

- **Running on their own laptop, not Codespaces?** Point them at README → Option B. `./lab.sh setup` names what's missing:
  - *"Docker is installed but not running"* → start Docker Desktop, wait, re-run `./lab.sh setup`.
  - *"'kind' / 'kubectl' is not installed"* → the install command is printed underneath.
  - *"kubectl is pointing at '<something>', not the lab cluster"* → they're on a real cluster context. **Stop them before they paste more commands.** `kubectl config use-context kind-kyverno-lab`, or better, a new terminal with `export KUBECONFIG=$HOME/.kube/kyverno-lab` + `./lab.sh setup`.
- **`kyverno: command not found`** → the Kyverno CLI isn't installed (only needed for Scenario 3's offline check and the Last step). Codespaces has it; on a Mac `brew install kyverno`. They can skip those steps and still pass `check 3`.

- **Scenario 2, "but Kyverno is Running!"**: that's the point. Ask: *what does the API server use to reach the pods?* (the Service → its endpoints).
- **Scenario 2, someone scaled or restarted Kyverno**: doesn't help — the Service still points nowhere. Patch the selector (README).
- **Scenario 3 alt fix**: `kubectl label ns shop env=production` also makes `check 3` pass.
  Accept it, then ask: *"Which is the real bug — the policy or the namespace?"*
- **`./lab.sh ci` shows ❌ on the broken policy**: that's correct! The gate is *supposed* to block it. ✅ is for the fixed policy.
- **Codespace too slow / quota hit**: pair them with a neighbour, or point them at the recording.
- **Someone ran `break` on another lab**: labs are independent; `./lab.sh reset` here fixes ours.

## One-line answers

1. Pods are created by the ReplicaSet controller, so the denial shows up in **RS events**, not your terminal.
2. Kyverno pods are fine, but `kyverno-svc` selects the wrong label → no endpoints → webhook `failurePolicy: Fail` → every change denied.
3. `READY` ≠ working. The namespaceSelector key is `env`, the namespace label is `environment`.

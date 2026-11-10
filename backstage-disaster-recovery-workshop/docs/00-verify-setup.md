# Part 0: Verify Setup

> [!TIP]
> Reading this as plain text? Press **Cmd+Shift+V** (Mac) or **Ctrl+Shift+V** (Windows/Linux) to see it formatted.

**Important: all the following steps must be performed in your newly created Codespace.**

These pages are the long version of the lab: you type the real `kubectl`, `curl` and `psql` commands yourself. Each step also names its `make` shortcut, which runs the same commands and prints them on lines starting with `$`.

## 1. Do you trust the authors of the files in this folder?

If you get a `Do you trust the authors of the files in this folder?` dialogue, make sure to press the green `Trust Folder & Continue` button, otherwise the workshop may not run.

## 2. Start the guided tour (optional, recommended)

The whole lab is also a guided tour: instructions next to the code, every command is a click, and a **Next** button. The tour is the short version: it runs the `make` shortcuts.

When the Codespace opens, CodeTour asks whether to start the tour **#1 - Backstage disaster recovery**. Select **Start Tour**.

If you dismissed it: open the Command Palette (Cmd/Ctrl+Shift+P) and run **CodeTour: Start Tour**.

Prefer reading? Keep going here; these pages and the tour are the same lab.

## 3. Check that Backstage is ready

The terminal starts in the workshop folder. Run every command in this lab from there.

Wait until Kubernetes reports the Backstage Deployment as rolled out, then ask Backstage itself:

```bash
kubectl -n backstage rollout status deploy/backstage --timeout=300s
curl -fsS http://localhost:7007/.backstage/health/v1/readiness
```

```
deployment "backstage" successfully rolled out
```

The `curl` prints Backstage's health answer once it is ready. If it fails, wait a few seconds and run it again.

If `kubectl` cannot reach a cluster, or `backstage` is not found, the setup is still running. Wait a minute and try again. To watch it: Command Palette > **Codespaces: View Creation Log**.

Print the portal address:

```bash
echo "https://${CODESPACE_NAME}-7007.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
```

```
https://<your-codespace>-7007.app.github.dev
```

> Shortcut: `make ui` does all of this, and also checks that Backstage is configured for this same URL.

## 4. Open the portal in a new browser tab and keep it open

The portal does not open by itself. Open the printed address in a **new browser tab** (Cmd/Ctrl+click it in the terminal), or open the **PORTS** tab and select the globe icon next to port 7007 (**Backstage**).

Select **ENTER** under **Guest**. You see the **Boring Corp Catalog** with three components: `cart-service`, `checkout-api` and `checkout-web`.

**Keep this tab open for the whole lab.** You come back to it after every step.

## 5. See what runs in Kubernetes

```bash
kubectl -n backstage get pods
```

```
NAME                             READY   STATUS    RESTARTS   AGE
backstage-6d9c8b7f5d-q2x7k       1/1     Running   0          4m
db-proxy-7f6b9c4d8-x5tlp         1/1     Running   0          4m
legacy-billing-5c8d7b6f9-m4k2p   1/1     Running   0          5m
postgres-0                       1/1     Running   0          5m
```

> Shortcut: `make k8s`.

That is the whole of Backstage: a stateless `backstage` pod (the portal and its API), and `postgres-0`, the database on its own disk. Everything you do in the portal ends up in Postgres.

`db-proxy` is **lab only**: it stands in for the network between the two, so Part 3 can make the database slow or unreachable.

`legacy-billing` is a sample legacy billing workload, built by one of our developer teams. We will use it later in the lab.

# Next: [Part 1: Seed](01-seed.md)

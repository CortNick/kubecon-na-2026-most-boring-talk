# Part 0: Verify Setup

> [!TIP]
> Reading this as plain text? Press **Cmd+Shift+V** (Mac) or **Ctrl+Shift+V** (Windows/Linux) to see it formatted.

**Important: all the following steps must be performed in your newly created Codespace.**

## 1. Do you trust the authors of the files in this folder?

If you get a `Do you trust the authors of the files in this folder?` dialogue, make sure to press the green `Trust Folder & Continue` button, otherwise the workshop may not run.

## 2. Start the guided tour (optional, recommended)

The whole lab is also a guided tour: instructions next to the code, every command is a click, and a **Next** button.

When the Codespace opens, CodeTour asks whether to start the tour **#1 - Backstage disaster recovery**. Select **Start Tour**.

If you dismissed it: open the Command Palette (Cmd/Ctrl+Shift+P) and run **CodeTour: Start Tour**.

Prefer reading? Keep going here; these pages and the tour are the same lab.

## 3. Check that Backstage is ready

In the terminal, run:

```bash
make ui
```

If it says the setup is still running, rerun it with `watch`, which will run it repeatedly till it succeeds:

```bash
watch make ui
```

Eventually you will see:

```
✔ Backstage is ready

Portal: https://<your-codespace>-7007.app.github.dev
Sign in: select ENTER under 'Guest'.
✔ Check: Backstage is configured for this same URL, so the API calls from your browser will work.
```

You can stop the `watch` command with Ctrl+C or open a new terminal.

## 4. Open the portal and keep it open

The portal usually opens by itself in a **Simple Browser** tab inside the editor. If it did not, open the printed **Portal** URL, or open the **PORTS** tab and select the globe icon next to port 7007 (**Backstage**).

Select **ENTER** under **Guest**. You see the **Boring Corp Catalog** with three components: `cart-service`, `checkout-api` and `checkout-web`.

**Keep this tab open for the whole lab.** You come back to it after every step.

## 5. See what runs in Kubernetes

```bash
make k8s
```

```
$ kubectl -n backstage get pods -l 'app in (backstage,postgres,db-proxy)'
NAME                         READY   STATUS    RESTARTS   AGE
backstage-6d9c8b7f5d-q2x7k   1/1     Running   0          4m
db-proxy-7f6b9c4d8-x5tlp     1/1     Running   0          4m
postgres-0                   1/1     Running   0          5m
```

That is the whole of Backstage: a stateless `backstage` pod (the portal and its API), and `postgres-0`, the database on its own disk. Everything you do in the portal ends up in Postgres.

`db-proxy` is **lab only**: it stands in for the network between the two, so Part 2 can make the database slow or unreachable.

Every `make` target in this lab prints the commands it runs, on lines starting with `$`. Copy any of them into the terminal to run it yourself.

# Next: [Part 1: Seed](01-seed.md)

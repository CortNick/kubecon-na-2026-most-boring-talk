# Part 2: Disaster

> [!TIP]
> Reading this as plain text? Press **Cmd+Shift+V** (Mac) or **Ctrl+Shift+V** (Windows/Linux) to see it formatted.

Four failures, from harmless to the real disaster. (7 minutes)

| Failure | Data lost? |
| --- | --- |
| 1. The Backstage pod dies | No |
| 2. The database gets slow | No |
| 3. The database becomes unreachable | No |
| 4. The database disk dies | Yes, unless you restore |

Every command prints what it runs on lines starting with `$`.

## 1. Kill the Backstage pod

```bash
make kill-backstage
```

```
$ kubectl -n backstage delete pod -l app=backstage --wait=false
pod "backstage-6d9c8b7f5d-q2x7k" deleted
$ kubectl -n backstage get pods -l app=backstage
NAME                         READY   STATUS              RESTARTS   AGE
backstage-6d9c8b7f5d-q2x7k   1/1     Terminating         0          9m
backstage-6d9c8b7f5d-w8m3c   0/1     ContainerCreating   0          1s
...
✔ Backstage is back in ...s, on the same database.
```

The Deployment notices the missing pod and starts a new one. Reload the portal (select **ENTER** under **Guest** if asked): the same catalog, the same tasks, the same 11 entities. **Nothing is lost**: Backstage keeps nothing itself, everything is in Postgres or in config.

## 2. The database gets slow

Backstage does not talk to Postgres directly in this lab. It goes through `db-proxy` ([manifests/db-proxy.yaml](../manifests/db-proxy.yaml)), a [Toxiproxy](https://github.com/Shopify/toxiproxy) pod that stands in for the network, so the lab can break it on purpose.

```bash
make db-slow
```

```
$ kubectl -n backstage exec deploy/db-proxy -- /toxiproxy-cli toxic add -t latency -n slow -a latency=1000 postgres
```

Every reply from the database now arrives 1 second late. Click around the portal: **Catalog**, a component, **Create** > **Tasks**. Everything works, slowly. The terminal times one API call with `time curl ...`.

Look at the pod: still **Ready**. Kubernetes' health checks do not see a slow database, so nothing alerts and nothing restarts. Your users just wait.

> [!TIP]
> Want it slower? `make db-heal`, then `make db-slow LATENCY=3000`.

## 3. The database becomes unreachable

```bash
make db-unreachable
```

```
$ kubectl -n backstage exec deploy/db-proxy -- /toxiproxy-cli toxic add -t timeout -n unreachable -a timeout=0 postgres
$ kubectl -n backstage exec postgres-0 -- pg_isready
/tmp:5432 - accepting connections
$ curl -sf --max-time 10 'http://localhost:7007/api/catalog/entities/by-query?limit=1' | jq .totalItems
(no answer)
```

Every byte between Backstage and Postgres now disappears, like a network partition. Postgres itself is fine (`pg_isready`), and so is its disk. Reload the portal: the page loads (static files), but every call hangs, then fails. The Backstage pod is **still Ready**, and restarting it would not help: the new pod could not reach the database either.

Fix the network:

```bash
make db-heal
```

```
$ kubectl -n backstage rollout restart deploy/db-proxy
...
✔ The API answers again after ...s, without restarting Backstage.
```

Backstage reconnects by itself. Reload the portal: 11 entities and 2 tasks, as before. **Slow and unreachable cost you time, not data.**

## 4. Lose the database disk

Now the real disaster:

```bash
make disaster
```

This deletes the Postgres PersistentVolumeClaim and its pod ([manifests/postgres.yaml](../manifests/postgres.yaml)). Kubernetes immediately starts a new Postgres, on a new, **empty** disk. This is how the disk failure is simulated, as the terminal prints it:

```
$ kubectl -n backstage scale statefulset/postgres --replicas=0
$ kubectl -n backstage wait --for=delete pod/postgres-0 --timeout=120s
$ kubectl -n backstage delete pvc data-postgres-0 --ignore-not-found --wait=true
$ kubectl -n backstage scale statefulset/postgres --replicas=1
```

Postgres stops, its disk is deleted (that is the failure), and the StatefulSet creates a new pod with a new, empty disk.

## 5. Watch the portal fail

Reload the portal tab. The page itself still loads, but you are back on the sign-in page, and **ENTER** does nothing: signing in needs the database, like every other API call.

```bash
make status
```

```
# Is everything running? (what Kubernetes sees)
$ kubectl -n backstage get pods
NAME                         READY   STATUS    RESTARTS   AGE
backstage-6d9c8b7f5d-w8m3c   1/1     Running   0          6m
...
postgres-0                   1/1     Running   0          20s

# How many catalog entities does the API return?
$ curl -sf --max-time 10 'http://localhost:7007/api/catalog/entities/by-query?limit=1' | jq .totalItems
(no answer)
```

The Backstage pod is still **Ready**: Kubernetes thinks everything is fine. This time healing the network would not help: Backstage creates its databases and tables only when it starts, and the new Postgres is empty.

## 6. Restart Backstage on the empty database

This is what most people try first:

```bash
make restart-backend
```

It runs `kubectl -n backstage rollout restart deploy/backstage`: Kubernetes replaces the Backstage pod. Backstage starts, creates fresh, empty databases and the portal works again. Reload the portal and select **ENTER** under **Guest** again: your old session was signed with keys that were in the database.

> [!NOTE]
> If a dialog asks *"Failed to sign in as a guest using the auth backend. Do you want to fallback to the legacy guest token?"*, select **Cancel**, reload the page and select **ENTER**. It is left over from clicking **ENTER** while the database was gone.

But look closely:

| Where to click | What you see |
| --- | --- |
| **Catalog** | `cart-service`, `checkout-api`, `checkout-web` are back. `legacy-billing` is **gone** |
| **Create** > **Tasks** | **Empty.** Both template runs are gone |
| **Create** | The **Create a lab service** template is back |
| **Search** (sidebar), type `checkout` | Results are back |

```bash
make status
```

The API answers again: **9** entities, **0** tasks, **0** components registered through the portal.

## 7. Why did those three come back?

```bash
make catalog-source
```

```
# 1. Backstage's config lists two catalog files to read on every start
$ kubectl -n backstage exec deploy/backstage -- grep -A6 '^catalog:' /config/app-config.lab.yaml
...
  locations:
    - type: file
      target: /catalog/all.yaml
    - type: file
      target: /catalog/template.yaml

# 2. Those files are a ConfigMap, mounted into the pod at /catalog
$ kubectl -n backstage get configmap backstage-catalog
...

# 3. The components in it: the three that came back
$ kubectl -n backstage exec deploy/backstage -- grep -A1 '^kind: Component' /catalog/all.yaml
...
```

The seed catalog and the template are **config locations**: files in Git ([manifests/catalog/all.yaml](../manifests/catalog/all.yaml)), put into a ConfigMap by the setup, mounted into the pod, and read by Backstage on every start ([manifests/app-config.lab.yaml](../manifests/app-config.lab.yaml)). Backstage rebuilds the search index from the catalog. Task history and anything registered through the portal (`legacy-billing`) exist only as rows in Postgres, so they are gone with the disk.

# Next: [Part 3: Restore](03-restore.md)

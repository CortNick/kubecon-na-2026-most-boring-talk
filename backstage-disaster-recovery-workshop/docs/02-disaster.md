# Part 2: Disaster

> [!TIP]
> Reading this as plain text? Press **Cmd+Shift+V** (Mac) or **Ctrl+Shift+V** (Windows/Linux) to see it formatted.

Two failures: one harmless, one the real disaster. (5 minutes)

| Failure | Data lost? |
| --- | --- |
| 1. The Backstage pod dies | No |
| 2. The database disk dies | Yes, unless you restore |

## 1. Kill the Backstage pod

Delete the pod, then watch its Deployment replace it:

```bash
kubectl -n backstage delete pod -l app=backstage --wait=false
kubectl -n backstage get pods -l app=backstage
kubectl -n backstage rollout status deploy/backstage --timeout=300s
```

```
pod "backstage-6d9c8b7f5d-q2x7k" deleted
NAME                         READY   STATUS              RESTARTS   AGE
backstage-6d9c8b7f5d-q2x7k   1/1     Terminating         0          9m
backstage-6d9c8b7f5d-w8m3c   0/1     ContainerCreating   0          1s
deployment "backstage" successfully rolled out
```

Did we lose anything? (11 entities and 2 tasks before.)

```bash
curl -sf --max-time 10 'http://localhost:7007/api/catalog/entities/by-query?limit=1' | jq .totalItems
curl -sf --max-time 10 http://localhost:7007/api/scaffolder/v2/tasks | jq '.tasks | length'
```

> Shortcut: `make kill-backstage`.

Reload the portal (select **ENTER** under **Guest** if asked): the same catalog, the same tasks, the same 11 entities. **Nothing is lost**: Backstage keeps nothing itself, everything is in Postgres or in config.

## 2. Lose the database disk

Now the real disaster. Postgres keeps its data on a PersistentVolumeClaim ([manifests/postgres.yaml](../manifests/postgres.yaml)). Stop Postgres, delete its disk, and start it again:

```bash
kubectl -n backstage scale statefulset/postgres --replicas=0
kubectl -n backstage wait --for=delete pod/postgres-0 --timeout=120s
kubectl -n backstage delete pvc data-postgres-0 --ignore-not-found --wait=true
kubectl -n backstage scale statefulset/postgres --replicas=1
kubectl -n backstage rollout status statefulset/postgres --timeout=300s
```

> Shortcut: `make disaster`.

The `delete pvc` line is the failure. The StatefulSet then creates a new Postgres pod with a new, **empty** disk.

## 3. Watch the portal fail

Reload the portal tab. The page itself still loads, but you are back on the sign-in page, and **ENTER** does nothing: signing in needs the database, like every other API call.

```bash
kubectl -n backstage get pods
curl -sf --max-time 10 'http://localhost:7007/api/catalog/entities/by-query?limit=1' | jq .totalItems
```

```
NAME                         READY   STATUS    RESTARTS   AGE
backstage-6d9c8b7f5d-w8m3c   1/1     Running   0          6m
...
postgres-0                   1/1     Running   0          20s
```

The `curl` gives no answer. The Backstage pod is still **Ready**: Kubernetes thinks everything is fine. Backstage creates its databases and tables only when it starts, and the new Postgres is empty, so it does not recover on its own.

> Shortcut: `make status`.

## 4. Restart Backstage on the empty database

Some people might know or guess that they need to restart Backstage at this point:

```bash
kubectl -n backstage rollout restart deploy/backstage
kubectl -n backstage rollout status deploy/backstage --timeout=300s
```

> Shortcut: `make restart-backend`.

Kubernetes replaces the Backstage pod. Backstage starts, creates fresh, empty databases, and the portal works again. Reload the portal and select **ENTER** under **Guest** again: your old session was signed with keys that were in the database.

> [!NOTE]
> If a dialog asks *"Failed to sign in as a guest using the auth backend. Do you want to fallback to the legacy guest token?"*, select **Cancel**, reload the page and select **ENTER**. It is left over from clicking **ENTER** while the database was gone.

## 5. What came back, what did not

| Where to click | What you see |
| --- | --- |
| **Catalog** | `cart-service`, `checkout-api`, `checkout-web` are back. `legacy-billing` is **gone** |
| **Create** > **Tasks** | **Empty.** Both template runs are gone |
| **Create** | The **Create a lab service** template is back |
| **Search** (sidebar), type `checkout` | Results are back |

Check the numbers again:

```bash
curl -sf --max-time 10 'http://localhost:7007/api/catalog/entities/by-query?limit=1' | jq .totalItems
curl -sf --max-time 10 http://localhost:7007/api/scaffolder/v2/tasks | jq '.tasks | length'
curl -sf --max-time 10 http://localhost:7007/api/catalog/locations | jq 'map(select(.data.type == "url")) | length'
```

```
9
0
0
```

## 6. Why did those three come back?

Backstage's config lists two catalog files to read on every start:

```bash
kubectl -n backstage exec deploy/backstage -- grep -A6 '^catalog:' /config/app-config.lab.yaml
```

```
...
  locations:
    - type: file
      target: /catalog/all.yaml
    - type: file
      target: /catalog/template.yaml
```

Those files are a ConfigMap, mounted into the pod at `/catalog`:

```bash
kubectl -n backstage get configmap backstage-catalog
kubectl -n backstage exec deploy/backstage -- ls /catalog
```

And the components in it are the three that came back:

```bash
kubectl -n backstage exec deploy/backstage -- grep -A1 '^kind: Component' /catalog/all.yaml
```

> Shortcut: `make catalog-source`.

The seed catalog and the template are **config locations**: files in Git ([manifests/catalog/all.yaml](../manifests/catalog/all.yaml)), put into a ConfigMap by the setup, mounted into the pod, and read by Backstage on every start ([manifests/app-config.lab.yaml](../manifests/app-config.lab.yaml)). Backstage rebuilds the search index from the catalog. Task history and anything registered through the portal (`legacy-billing`) exist only as rows in Postgres, so they are gone with the disk.

Some data comes back on its own; the rest is lost unless you plan for it.

# Next: [Part 2: Restore](03-restore.md)

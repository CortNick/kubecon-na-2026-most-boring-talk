# Part 2: Disaster

> [!TIP]
> Reading this as plain text? Press **Cmd+Shift+V** (Mac) or **Ctrl+Shift+V** (Windows/Linux) to see it formatted.

The disk under Postgres dies. (4 minutes)

## 1. Lose the database

```bash
make disaster
```

This deletes the Postgres PersistentVolumeClaim and its pod ([manifests/postgres.yaml](../manifests/postgres.yaml)). Kubernetes immediately starts a new Postgres, on a new, **empty** disk. The clock starts now: `make status` shows the time since the disaster from here on.

This is how the disk failure is simulated, as the terminal prints it:

```
$ kubectl -n backstage scale statefulset/postgres --replicas=0
$ kubectl -n backstage wait --for=delete pod/postgres-0 --timeout=120s
$ kubectl -n backstage delete pvc data-postgres-0 --ignore-not-found --wait=true
$ kubectl -n backstage scale statefulset/postgres --replicas=1
```

Postgres stops, its disk is deleted (that is the failure), and the StatefulSet creates a new pod with a new, empty disk.

## 2. Watch the portal fail

Reload the portal tab. The page itself still loads (it is static files in the Backstage container), but you are back on the sign-in page, and **ENTER** does nothing: signing in needs the database, like every other API call.

```bash
make status
```

```
  Backstage pod (Kubernetes)   Ready
  Backstage portal and API     DOWN (the portal and its API do not answer)
```

The Backstage pod is still **Ready**: Kubernetes thinks everything is fine. Backstage creates its databases and tables only when it starts, so it does not recover on its own while Postgres is empty.

## 3. Restart Backstage on the empty database

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

```
  Catalog entities             9
  Scaffolder tasks             0
  Registered locations         0
```

**Why?** The seed catalog and the template are config locations: Backstage reads them from files ([manifests/app-config.lab.yaml](../manifests/app-config.lab.yaml)) on every start, and rebuilds the search index from the catalog. Task history and anything registered through the portal exist only as rows in Postgres, so they are gone with the disk.

# Next: [Part 3: Restore](03-restore.md)

# Part 2: Restore

> [!TIP]
> Reading this as plain text? Press **Cmd+Shift+V** (Mac) or **Ctrl+Shift+V** (Windows/Linux) to see it formatted.

Run the recovery runbook. (3 minutes)

## 1. Restore the backup

Restoring the database takes four steps: stop Backstage, start a fresh Postgres, load the newest backup with `psql`, and start Backstage. The same steps are in [scripts/restore.sh](../scripts/restore.sh).

**Step 1: stop Backstage**, so nothing writes while you restore:

```bash
kubectl -n backstage scale deploy/backstage --replicas=0
kubectl -n backstage wait --for=delete pod -l app=backstage --timeout=120s
```

**Step 2: start a fresh, empty Postgres on a new disk**, the same commands as losing the disk:

```bash
kubectl -n backstage scale statefulset/postgres --replicas=0
kubectl -n backstage wait --for=delete pod/postgres-0 --timeout=120s
kubectl -n backstage delete pvc data-postgres-0 --ignore-not-found --wait=true
kubectl -n backstage scale statefulset/postgres --replicas=1
kubectl -n backstage rollout status statefulset/postgres --timeout=300s
```

**Step 3: load the newest backup with `psql`.** The dump also drops and recreates the `backstage` role, which `psql` is connected as, so skip those two lines; the fresh Postgres already has that role:

```bash
BACKUP=$(ls -1 backups/*.sql | sort | tail -1); echo "${BACKUP}"
grep -vE '^(DROP ROLE IF EXISTS|CREATE ROLE) backstage;$' "${BACKUP}" \
  | kubectl -n backstage exec -i postgres-0 -- env PGOPTIONS='-c client_min_messages=warning' \
      psql -q -v ON_ERROR_STOP=1 -d postgres > /dev/null
```

**Step 4: start Backstage again:**

```bash
kubectl -n backstage scale deploy/backstage --replicas=1
kubectl -n backstage rollout status deploy/backstage --timeout=300s
```

> Shortcut: `make restore` runs all four steps and prints each command.

## 2. Check that everything is back

| Where to click | What you see |
| --- | --- |
| **Catalog** | `legacy-billing` is back |
| **Create** > **Tasks** | Both template runs are back |

```bash
curl -sf --max-time 10 'http://localhost:7007/api/catalog/entities/by-query?limit=1' | jq .totalItems
curl -sf --max-time 10 http://localhost:7007/api/scaffolder/v2/tasks | jq '.tasks | length'
curl -sf --max-time 10 http://localhost:7007/api/catalog/locations | jq 'map(select(.data.type == "url")) | length'
```

```
11
2
1
```

> Shortcut: `make status`.

The same numbers as before the disaster. If the first `curl` gives no answer, Backstage is still reading the catalog: wait a few seconds and run it again.

Ask yourself: for your internal developer portal, how long could it be down, and how much work could you lose? The answers set your backup frequency.

# Next: [Part 3: Not all disasters created equal](04-slow-and-unreachable.md)

# Part 3: Restore

> [!TIP]
> Reading this as plain text? Press **Cmd+Shift+V** (Mac) or **Ctrl+Shift+V** (Windows/Linux) to see it formatted.

Run the recovery runbook. (3 minutes)

## 1. Restore the backup

```bash
make restore
```

The runbook, in four steps ([scripts/restore.sh](../scripts/restore.sh)):

1. Stop Backstage, so nothing writes while you restore: `kubectl scale deploy/backstage --replicas=0`.
2. Start a fresh Postgres on a new disk: the same commands as `make disaster`.
3. Load the newest file in `backups/` with `psql`: `grep ... backups/<time>.sql | kubectl exec -i postgres-0 -- psql`.
4. Start Backstage again: `kubectl scale deploy/backstage --replicas=1`.

The terminal prints the full command for each step.

## 2. Check that everything is back

| Where to click | What you see |
| --- | --- |
| **Catalog** | `legacy-billing` is back |
| **Create** > **Tasks** | Both template runs are back |

```bash
make status
```

```
...
$ curl -sf --max-time 10 'http://localhost:7007/api/catalog/entities/by-query?limit=1' | jq .totalItems
11
...
$ curl -sf --max-time 10 http://localhost:7007/api/scaffolder/v2/tasks | jq '.tasks | length'
2
...
$ curl -sf --max-time 10 http://localhost:7007/api/catalog/locations | jq 'map(select(.data.type == "url")) | length'
1
```

The same numbers as before the disaster.

# Next: [Wrap-up](04-wrap-up.md)

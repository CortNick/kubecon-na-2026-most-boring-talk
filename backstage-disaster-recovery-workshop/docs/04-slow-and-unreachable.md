# Part 3: Not all disasters created equal

> [!TIP]
> Reading this as plain text? Press **Cmd+Shift+V** (Mac) or **Ctrl+Shift+V** (Windows/Linux) to see it formatted.

Two failures that cost you time, not data. (3 minutes)

| Failure | Data lost? |
| --- | --- |
| 1. The database gets slow | No |
| 2. The database becomes unreachable | No |

Backstage does not talk to Postgres directly in this lab. It goes through `db-proxy` ([manifests/db-proxy.yaml](../manifests/db-proxy.yaml)), a [Toxiproxy](https://github.com/Shopify/toxiproxy) pod that stands in for the network, so the lab can break it on purpose.

## 1. The database gets slow

Add a latency "toxic" to the proxy: every reply from the database now arrives 1 second (1000 ms) late.

```bash
kubectl -n backstage exec deploy/db-proxy -- /toxiproxy-cli toxic add -t latency -n slow -a latency=1000 postgres
kubectl -n backstage exec deploy/db-proxy -- /toxiproxy-cli inspect postgres
```

How long does one API call take now, and what does Kubernetes think?

```bash
time curl -sf --max-time 30 -o /dev/null -w '%{http_code}\n' 'http://localhost:7007/api/catalog/entities/by-query?limit=1'
kubectl -n backstage get pods -l app=backstage
```

> Shortcut: `make db-slow`.

Click around the portal: **Catalog**, a component, **Create** > **Tasks**. Everything works, slowly.

Look at the pod: still **Ready**. Kubernetes' health checks do not see a slow database, so nothing alerts and nothing restarts. Your users just wait.

> [!TIP]
> Want it slower? Remove the toxic and add it again with a bigger delay:
>
> ```bash
> kubectl -n backstage exec deploy/db-proxy -- /toxiproxy-cli toxic remove -n slow postgres
> kubectl -n backstage exec deploy/db-proxy -- /toxiproxy-cli toxic add -t latency -n slow -a latency=3000 postgres
> ```
>
> Shortcut: `make db-heal`, then `make db-slow LATENCY=3000`.

## 2. The database becomes unreachable

Now cut the network to the database completely. Maybe Postgres is dead, or maybe it is not coming back in the next 4 hours. A `timeout` toxic with `timeout=0` makes every byte to Postgres vanish, like a network partition:

```bash
kubectl -n backstage exec deploy/db-proxy -- /toxiproxy-cli toxic add -t timeout -n unreachable -a timeout=0 postgres
```

Is Postgres still fine? Does the API answer? What does Kubernetes think?

```bash
kubectl -n backstage exec postgres-0 -- pg_isready
curl -sf --max-time 10 'http://localhost:7007/api/catalog/entities/by-query?limit=1' | jq .totalItems
kubectl -n backstage get pods -l app=backstage
```

```
/tmp:5432 - accepting connections
```

> Shortcut: `make db-unreachable`.

Postgres itself is fine (`pg_isready`), and so is its disk, but the `curl` gives no answer. Reload the portal: the page loads (static files), but every call hangs, then fails. The Backstage pod is **still Ready**, and restarting it would not help: the new pod could not reach the database either.

## 3. Fix the network

Replace the proxy with a fresh one: no toxics, connections allowed. Backstage is **not** restarted.

```bash
kubectl -n backstage rollout restart deploy/db-proxy
kubectl -n backstage rollout status deploy/db-proxy --timeout=180s
```

Backstage reconnects by itself. Did we lose anything? (11 entities and 2 tasks before.) If the first `curl` gives no answer, wait a few seconds and run it again.

```bash
curl -sf --max-time 10 'http://localhost:7007/api/catalog/entities/by-query?limit=1' | jq .totalItems
curl -sf --max-time 10 http://localhost:7007/api/scaffolder/v2/tasks | jq '.tasks | length'
```

> Shortcut: `make db-heal`.

Reload the portal: everything is back, with the same numbers. **Slow and unreachable databases cost you time, not data.** Surviving them may require multi-AZ failover, which is tricky: make sure you really need it before you start.

# Next: [Wrap-up](05-wrap-up.md)

# Part 1: Seed

> [!TIP]
> Reading this as plain text? Press **Cmd+Shift+V** (Mac) or **Ctrl+Shift+V** (Windows/Linux) to see it formatted.

Use the portal like a normal team does on a normal day. Then take a backup. (4 minutes)

## 1. Create 2 new services with a software template

The template only logs: it has two `debug:log` steps and creates nothing ([manifests/catalog/template.yaml](../manifests/catalog/template.yaml)). Each run is recorded as a **scaffolder task**.

1. In the portal sidebar, select **Create**.
2. On **Create a lab service**, select **Choose**.
3. Enter a **Service name**, for example `my-service`, then **Review**, then **Create**. The task completes in a second.

Do it again with another name, for example `my-other-service`.

Then select **Create** > **Tasks**: both runs are listed.

## 2. Register an existing component

Not everything in a catalog comes from config. Teams also register their own repositories through the portal.

In this lab, the team's repository is `legacy-billing`: a small web server in the cluster ([manifests/legacy-billing.yaml](../manifests/legacy-billing.yaml)) that serves one file, [manifests/legacy-billing/catalog-info.yaml](../manifests/legacy-billing/catalog-info.yaml).

1. In the sidebar, select **Register Existing Component**.
2. In **URL**, enter:

   ```text
   http://legacy-billing.backstage.svc.cluster.local/catalog-info.yaml
   ```

3. Select **Analyze**, then **Import**.

The catalog now has a fourth component: `legacy-billing`.

> [!NOTE]
> If the import fails, make the same call through the API. Sign in as the guest user to get a token, then register the URL:
>
> ```bash
> TOKEN=$(curl -fsS -H 'X-Requested-With: XMLHttpRequest' http://localhost:7007/api/auth/guest/refresh | jq -r .backstageIdentity.token)
> curl -sS -X POST http://localhost:7007/api/catalog/locations \
>   -H "Authorization: Bearer ${TOKEN}" -H 'Content-Type: application/json' \
>   -d '{"type":"url","target":"http://legacy-billing.backstage.svc.cluster.local/catalog-info.yaml"}'
> ```
>
> Shortcut: `make register`.

## 3. Check the numbers

What Kubernetes sees:

```bash
kubectl -n backstage get pods
```

What the Backstage API returns: catalog entities, template runs (scaffolder tasks), and components registered through the portal:

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

(11 entities: the 9 from config, plus `legacy-billing` and the Location that points to it.)

> Shortcut: `make status` runs these, plus `ls backups/`.

## 4. Back up the database

`pg_dumpall` in the Postgres pod writes one dump of every database Backstage created (it creates one per plugin). Save it in `backups/`, named after the current time:

```bash
mkdir -p backups
kubectl -n backstage exec postgres-0 -- pg_dumpall --clean --if-exists > backups/$(date -u +%Y%m%dT%H%M%SZ).sql
ls -l backups/
date +%H:%M:%S
```

> Shortcut: `make backup`.

**Write down the backup time.** Anything you do after it is not in the backup.

# Next: [Part 2: Disaster](02-disaster.md)

# Part 1: Seed

> [!TIP]
> Reading this as plain text? Press **Cmd+Shift+V** (Mac) or **Ctrl+Shift+V** (Windows/Linux) to see it formatted.

Use the portal like a normal team does on a normal day. Then take a backup. (4 minutes)

## 1. Run a software template, twice

1. In the portal sidebar, select **Create**.
2. On **Create a lab service**, select **Choose**.
3. Enter a **Service name**, for example `my-service`, then **Review**, then **Create**.
4. The task runs two `debug:log` steps and completes. (The template only logs; it creates nothing.)

Do it again with another name, for example `my-other-service`.

Then select **Create** > **Tasks**: both runs are listed.

## 2. Register an existing component

Not everything in a catalog comes from config. Teams also register their own repositories through the portal.

1. In the sidebar, select **Register Existing Component**.
2. In **URL**, enter:

   ```text
   http://catalog-files.backstage.svc.cluster.local/catalog-info.yaml
   ```

3. Select **Analyze**, then **Import**.

The catalog now has a fourth component: `legacy-billing`. The file comes from a small web server in the cluster ([manifests/catalog-files/catalog-info.yaml](../manifests/catalog-files/catalog-info.yaml)), standing in for a team's repository.

> [!NOTE]
> If the import fails, run `make register` instead. It makes the same call through the API.

## 3. Check the numbers

```bash
make status
```

```
# Is everything running? (what Kubernetes sees)
$ kubectl -n backstage get pods
NAME                         READY   STATUS    RESTARTS   AGE
backstage-6d9c8b7f5d-q2x7k   1/1     Running   0          8m
...

# How many catalog entities does the API return?
$ curl -sf --max-time 10 'http://localhost:7007/api/catalog/entities/by-query?limit=1' | jq .totalItems
11

# How many template runs (scaffolder tasks)?
$ curl -sf --max-time 10 http://localhost:7007/api/scaffolder/v2/tasks | jq '.tasks | length'
2

# How many components were registered through the portal?
$ curl -sf --max-time 10 http://localhost:7007/api/catalog/locations | jq 'map(select(.data.type == "url")) | length'
1
...
```

(11 entities: the 9 from config, plus `legacy-billing` and the Location that points to it.)

Each answer is one plain command: `kubectl` for what Kubernetes sees, `curl` and `jq` against the Backstage API for the counts. Copy any `$` line into the terminal to run it yourself.

## 4. Back up the database

```bash
make backup
```

This runs `pg_dumpall` in the Postgres pod: one dump of every database Backstage created (it creates one per plugin). It prints the exact command:

```
$ kubectl -n backstage exec postgres-0 -- pg_dumpall --clean --if-exists > backups/<time>.sql
```

**Write down the backup time it prints.** Anything you do after it is not in the backup.

# Next: [Part 2: Disaster](02-disaster.md)

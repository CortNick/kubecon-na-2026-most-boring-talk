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
  Catalog entities             11
  Scaffolder tasks             2
  Registered locations         1
```

(11 entities: the 9 from config, plus `legacy-billing` and the Location that points to it.)

Above the numbers, `make status` prints how it reads each one: `kubectl` for the pods, and `curl` against the Backstage API for the counts.

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

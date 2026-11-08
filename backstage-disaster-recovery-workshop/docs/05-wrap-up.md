# Wrap-up

## What you saw

| | Comes back by itself | Gone unless restored from backup |
| --- | --- | --- |
| What | Catalog entities and templates from config locations, the search index | Scaffolder task history, components registered through the portal |
| Why | Backstage reads them from files on every start | They exist only as rows in Postgres |

Backstage is stateless containers plus one Postgres. Losing the containers costs you a restart. Losing Postgres costs you everything that is not in Git. A slow or unreachable Postgres costs you time, not data, and Kubernetes does not notice either.

## Three things to take home

1. **Back up Postgres, per your RTO and RPO.** Decide how much downtime (RTO) and data loss (RPO) your team accepts. Nightly dump: up to a day lost. Managed Postgres with point-in-time recovery: minutes. A standby in another zone or region: shorter downtime, but more complex to manage. Restoring to another region or cluster also needs network access (a proxy or DNS), certificates and credentials, label changes, and CRDs. Rehearse the restore, as you just did.
2. **Keep everything as code, in version control.** `app-config`, the catalog files, the templates, your Backstage app and its image tag: everything you can rebuild from Git, you do not have to back up.
3. **Make sure your dependencies are available.** A backup you cannot connect to does not help, and neither does a code repository that is down.

## More

Finished early? [more/](../more/README.md) loses an availability zone instead of a disk.

## Clean up

Delete your Codespace from <https://github.com/codespaces>.

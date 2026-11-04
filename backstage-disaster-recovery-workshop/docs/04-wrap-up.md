# Wrap-up

## What you saw

| | Comes back by itself | Gone unless restored from backup |
| --- | --- | --- |
| What | Catalog entities and templates from config locations, the search index | Scaffolder task history, components registered through the portal |
| Why | Backstage reads them from files on every start | They exist only as rows in Postgres |

Backstage is stateless containers plus one Postgres. Losing the containers costs you a restart. A slow or unreachable Postgres costs you time, not data, and Kubernetes does not notice either. Losing Postgres costs you everything that is not in Git.

## Three things to do for your real Backstage

1. **Decide how much downtime (RTO) and data loss (RPO) your team accepts, then back up and place Postgres for that.** A nightly `pg_dump` gives you up to a day of RPO. Managed Postgres with point-in-time recovery gives you minutes. A standby in a second zone or a replica in a second region shortens RTO. Rehearse the restore, as you just did, and the slow and unreachable database too: on a real cluster, Chaos Mesh or LitmusChaos inject those faults without a proxy.
2. **Keep config and code in Git.** `app-config`, the catalog files, the templates, your Backstage app and its image tag: everything you can rebuild from Git, you do not have to back up.
3. **Keep secrets somewhere restorable.** The database password, integration tokens and auth provider secrets. A backup you cannot connect to does not help. Use a secrets manager, External Secrets Operator or Sealed Secrets.

## More

Finished early? [more/](../more/README.md) loses an availability zone instead of a disk.

## Clean up

Delete your Codespace from <https://github.com/codespaces>.

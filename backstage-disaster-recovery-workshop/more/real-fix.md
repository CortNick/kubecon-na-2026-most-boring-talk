# What the real fix looks like

The lab ran Postgres as one pod on one disk, because it fits in a Codespace. In production, the database is the only part of Backstage worth protecting, and how you protect it follows from the two numbers you wrote down.

| Your RTO / RPO | What to run |
| --- | --- |
| Hours / a day | Nightly `pg_dump` to object storage in another region. Restore by hand, as in the lab. Rehearse it |
| Under an hour / minutes | Managed Postgres (Amazon RDS or Aurora, Cloud SQL, Azure Database for PostgreSQL) with **point-in-time recovery**: restore to any second inside the retention window |
| Minutes / near zero, against a zone loss | Managed Postgres with a **synchronous standby in a second zone** (Multi-AZ, regional HA). Failover is automatic and takes a minute or two |
| Minutes / seconds, against a region loss | A **cross-region read replica** that you promote, plus Backstage deployable in that region from Git. RPO is the replication lag |

In Kubernetes, an operator such as CloudNativePG gives you the same building blocks: continuous WAL archiving to object storage (point-in-time recovery), replicas spread over zones, and a replica cluster in another region.

Whatever you choose:

- **Backstage itself stays stateless.** Run 2+ replicas spread over zones with a PodDisruptionBudget (as in this folder), and redeploy it from Git anywhere.
- **Back up, and test the restore.** A backup you never restored is a hope, not a backup. Measure the restore time: that is your real RTO.
- **Keep the secrets restorable.** The database credentials, integration tokens and auth provider secrets live in a secrets manager that survives the same disaster.

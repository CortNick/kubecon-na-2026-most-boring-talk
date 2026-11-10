# More: lose an availability zone

> [!TIP]
> Reading this as plain text? Press **Cmd+Shift+V** (Mac) or **Ctrl+Shift+V** (Windows/Linux) to see it formatted.

For early finishers and day-two readers. The lab lost a disk. This one loses a whole availability zone. (10 minutes, plus a few minutes of image pulls)

It uses a **second** kind cluster, `backstage-zones`, with two nodes labelled `topology.kubernetes.io/zone: zone-a` and `zone-b` ([kind-config-zones.yaml](kind-config-zones.yaml)). Its portal is on port **7008**, so the lab cluster can keep running. On a 4-core Codespace, run `make teardown` first if things feel slow.

| File | What it is |
| --- | --- |
| [kind-config-zones.yaml](kind-config-zones.yaml) | Two nodes, one per zone |
| [backstage-ha-patch.yaml](backstage-ha-patch.yaml) | Backstage with 2 replicas and a `topologySpreadConstraints` on the zone label |
| [backstage-pdb.yaml](backstage-pdb.yaml) | A PodDisruptionBudget: at least one Backstage replica stays up during a drain |
| [zone-failure.sh](zone-failure.sh) | Creates the cluster, cordons and drains a zone, heals it |

## 1. Start the two-zone cluster

```bash
more/zone-failure.sh up
```

One Backstage replica runs in each zone. Postgres runs in one of them.

> [!NOTE]
> The script starts Backstage with one replica, then scales to two. Two replicas starting at the same time on an empty database race on the schema migrations and can both get stuck on the migration lock. Keep this in mind for any multi-replica Backstage: let one instance migrate first.

## 2. Lose the zone without Postgres

```bash
more/zone-failure.sh fail
```

The script cordons and drains the zone that does **not** run Postgres. The Backstage replica there is evicted and starts again in the other zone. The portal stays **UP** throughout: the stateless part of Backstage survives a zone loss as soon as it runs in more than one zone.

```bash
more/zone-failure.sh heal
```

## 3. Lose the zone with Postgres

```bash
more/zone-failure.sh fail zone-a   # or zone-b: whichever 'status' shows Postgres in
```

Now the portal goes **DOWN**, and Postgres stays **Pending**. Its disk (a kind local-path volume, like a cloud block volume) exists in one zone only, so Postgres cannot start anywhere else. The drain does not finish either: the PodDisruptionBudget will not evict the last Backstage replica, even though it can no longer reach its database.

Two replicas and a spread constraint protect the part that did not need protecting. The database is still a single point of failure in a single zone.

```bash
more/zone-failure.sh heal     # the zone comes back, Postgres starts again on its disk
more/zone-failure.sh down     # delete the two-zone cluster
```

## What the real fix looks like

See [real-fix.md](real-fix.md).

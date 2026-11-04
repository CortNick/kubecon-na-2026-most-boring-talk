# Facilitator notes

## Before the workshop

- The dev container configuration is `.devcontainer/backstage-dr-workshop/devcontainer.json` at the repository root (Codespaces only looks there). It opens this folder, runs `scripts/post-create.sh` to install kind and jq and write the tour, then `make setup` to create the cluster and start Postgres and Backstage. `postStartCommand` runs `make setup` again on every start, so a cluster exists after a Codespace restart or when the Codespace comes from a prebuild (prebuilds do not keep Docker volumes). On an existing cluster it takes a few seconds.
- Create your own demo Codespace before the talk, so it's ready on stage. Run `make reset` right before you go on.
- Ask participants to bring a GitHub account with Codespaces quota, and to set their default idle timeout to 90 minutes (see the [README](../README.md)).
- Image pulls per Codespace: `ghcr.io/backstage/backstage` (the big one), `ghcr.io/cloudnative-pg/postgresql`, `ghcr.io/nginxinc/nginx-unprivileged` from ghcr.io, and the kind node image `kindest/node` from **Docker Hub**. The node image is unavoidable (kind publishes it only there). It is a single pull per Codespace, anonymous, from Codespaces' own IP addresses. Every image is pinned by digest in [scripts/versions.env](../scripts/versions.env). After the pulls, the lab makes no external network calls.
- `ghcr.io/nginxinc/nginx-unprivileged:1.27.4-alpine-slim` is the newest nginx tag on ghcr.io. It only serves one static file inside the cluster.

## Timing (10 minutes, live)

Command times measured end to end with kind on a 4-CPU / 8 GiB Docker VM (Apple silicon, colima), from [scripts/e2e.sh](../scripts/e2e.sh). Codespaces is usually a bit slower; check them in your dry run.

| Part | Minutes | You run | Command time | Notes |
| --- | --- | --- | --- | --- |
| Setup | during the intro | (automatic) | 41s cold on the laptop, cluster create to portal ready, images pulled fresh | Show a QR code for `https://github.com/reggie-k/kubecon-na-2026-most-boring-talk/tree/main/backstage-disaster-recovery-workshop`. Its README walks participants through creating a Codespace |
| 0. Verify | 1 | `make ui`, sign in as Guest | 1s | Show the portal in the Simple Browser, and the CodeTour panel |
| 1. Seed | 3 | Template twice and Register Existing Component in the UI, `make status`, `make backup` | backup: 1s | Short on time: `make seed` does the template runs and the registration through the API in under a second |
| 2. Disaster | 3 | `make disaster`, reload the portal, `make status`, `make restart-backend`, click Catalog, Create > Tasks, Search | disaster: 5–6s, restart-backend: 4–5s | The punchline: the pod is **Ready** while the portal is down. After the restart, 3 components are back, Tasks is empty, `legacy-billing` is gone |
| 3. Restore | 2 | `make restore`, click Catalog and Tasks | restore: 10–15s | Walk through the four printed steps; the RTO/RPO question comes in the wrap-up |
| Wrap-up | 1 | | | The three things in [04-wrap-up.md](04-wrap-up.md) |
| Between runs | | `make reset` | 24–42s | Deletes the namespace (including the Postgres disk), the backups and the disaster time, and starts everything again. The kind cluster stays |

Attendees doing it self-paced need about 15 minutes after the setup: the docs give 1 + 4 + 4 + 3 + 2 minutes, mostly reading and clicking.

## Lab-only settings

[manifests/app-config.lab.yaml](../manifests/app-config.lab.yaml) has settings you must not copy to production. Say so if someone asks:

| Setting | Why it is in the lab | In production |
| --- | --- | --- |
| `backend.csp.frame-ancestors: ['*']` | Lets VS Code's Simple Browser show the portal inside the editor. Backstage also always sends `X-Frame-Options: DENY`; browsers ignore that header when the CSP has `frame-ancestors` (verified in Chromium: the portal renders in an iframe from another origin) | Leave it out, or list only your own origins. Any site could otherwise frame your portal (clickjacking) |
| `backend.auth.dangerouslyDisableDefaultAuthPolicy: true` | Lets `make status` read the API with plain `curl`, no token | Leave it out. Every API call needs a user or service token |
| `auth.providers.guest.dangerouslyAllowOutsideDevelopment: true` | The image runs in production mode, where guest sign-in is off | Use a real sign-in provider |
| The Postgres password in [manifests/postgres.yaml](../manifests/postgres.yaml) | A plain Secret, so the lab needs nothing else | A secrets manager, which is also part of the lesson |

## How it works, in case you get asked

- `make backup` runs `pg_dumpall --clean --if-exists` in the Postgres pod. Backstage creates one database per plugin (`backstage_plugin_catalog`, `backstage_plugin_scaffolder`, `backstage_plugin_search`, ...); the dump has all of them.
- `make disaster` scales the Postgres StatefulSet to 0, deletes its PersistentVolumeClaim (kind's local-path storage deletes the data with it) and scales it back to 1 on a new, empty volume.
- Backstage creates its tables only when it starts. After the database is replaced it answers every API call with HTTP 500 (the readiness probe stays green) until it is restarted. That is why `make restart-backend` exists, and why `make restore` stops Backstage first and starts it after the load.
- After the empty restart, the 9 entities from the config locations (a group, a user, a system, 3 components, the template and the 2 Location entities for the files) come back within seconds. The search index is rebuilt from the catalog within a few seconds. Task history and the registered location are gone.
- After `make restore`, the browser session still works: Backstage's signing keys are in the database and come back with it. After the empty restart everyone signs in again.

## Helper cheat sheet: the five most likely mistakes

| What you see | Cause | Fix |
| --- | --- | --- |
| Portal page loads, but every page shows errors or stays empty | Backstage's configured URL is not the URL in the browser (for example the Codespace was renamed or the setup ran outside Codespaces) | `make ui` shows the check. If it fails: `make setup` |
| `make restore` says there is no backup | Skipped `make backup` in Part 1 | Nothing to restore, which is a lesson too. `make reset`, then start again at Part 1 |
| After the disaster, the portal stays broken | Did not run `make restart-backend` (or `make restore`) | Run `make restart-backend`, then reload the portal and select **ENTER** under **Guest** |
| A dialog offers a "legacy guest token" | Selected **ENTER** while the database was gone | **Cancel**, reload, **ENTER** |
| `No rule to make target` | Codespace created with the default dev container, not the Backstage one | Create a new Codespace with **Backstage disaster recovery workshop**. Check that the Explorer root is `backstage-disaster-recovery-workshop` |

Other things that can happen:

| Symptom | Fix |
| --- | --- |
| `make ui` says the setup is still running | Wait; `watch make ui`. To see progress: Command Palette > **Codespaces: View Creation Log** |
| `make ui` says the setup failed | Usually a temporary pull error. `make setup` again; it skips what's already done |
| Codespace stopped (idle timeout) | Reopen it. `postStartCommand` runs `make setup`. If `make status` shows the seed numbers are off, `make reset` and start at Part 1 |
| The CodeTour prompt did not appear | Command Palette > **CodeTour: Start Tour** |
| Register Existing Component fails | `make register` does the same through the API |

## Dry-run checklist (not verifiable outside Codespaces)

Everything else was run end to end on a laptop with kind. Check these in a real Codespace before the talk:

- [ ] Cold boot on a 4-core Codespace, from **Create codespace** to `make ui` saying ready, is under 5 minutes. Time it on a Codespace without a prebuild.
- [ ] The port 7007 auto-forward opens the portal in the Simple Browser (`onAutoForward: openPreview`), and the Codespaces port-forwarding sign-in redirect works inside it (private port).
- [ ] Guest sign-in works inside the Simple Browser (cookies inside the editor's frame), not only in a separate tab.
- [ ] The tour's **open it inside the editor** link (`simpleBrowser.show`) and the **open in a new tab** link both open the portal.
- [ ] CodeTour offers the tour when the Codespace opens. The tour is written by `post-create.sh` before `make setup`; check the prompt appears on first open and after a restart.
- [ ] `>> make ...` lines in the tour run in the integrated terminal.
- [ ] A Codespace restart (stop, start) brings the cluster back via `postStartCommand`.
- [ ] The `gh codespace create ... -m standardLinux32gb --idle-timeout 90m` one-liner in the README works against the final repository, and the README's Codespaces button opens the right dev container (it works only after the branch is merged).
- [ ] Image pulls when many Codespaces start at once (ghcr.io and Docker Hub for the kind node image).

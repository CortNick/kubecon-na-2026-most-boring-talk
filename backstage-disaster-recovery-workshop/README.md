# Backstage disaster recovery workshop overview

The disk under your Backstage database just died.
How long until the portal is back, and what did you lose?

Backstage is stateless containers plus one Postgres. In 15 minutes you use it, back it up, lose the database, and get it back:

| Step | What you do | Time |
| --- | --- | --- |
| [0. Verify setup](docs/00-verify-setup.md) | Open the portal inside the editor | 1 min |
| [1. Seed](docs/01-seed.md) | Run a template twice, register a component, back up | 4 min |
| [2. Disaster](docs/02-disaster.md) | Lose the Postgres disk, restart Backstage, see what came back | 4 min |
| [3. Restore](docs/03-restore.md) | Restore the backup and check what came back | 3 min |
| [4. Wrap-up](docs/04-wrap-up.md) | Three things to do for your real Backstage | 2 min |

Everything runs in a GitHub Codespace: a kind cluster with Postgres and Backstage, a guided tour (CodeTour) where every command is a click, and the portal in a tab inside the editor. No GitHub token, no fork and no push needed.

Finished early? [more/](more/README.md) loses an availability zone instead of a disk.

## Start here

Do this now, while the intro is running. The setup takes a few minutes and runs in the background.

You need a GitHub account with Codespaces quota (the free quota is enough). The Codespace is billed to your own account.

### 1. Set your default idle timeout to 90 minutes

Open <https://github.com/settings/codespaces>, set **Default idle timeout** to `90` minutes, and save. Otherwise the Codespace stops after 30 idle minutes and your cluster with it.

### 2. Create a Codespace

**In the browser:** select this button, then **Create codespace**.

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/reggie-k/kubecon-na-2026-most-boring-talk?devcontainer_path=.devcontainer/backstage-dr-workshop/devcontainer.json&machine=standardLinux32gb)

Or select **Code** > **Codespaces**, then **...** > **New with options**, and choose:

| Setting | Value |
| --- | --- |
| Branch | `main` |
| Dev container configuration | **Backstage disaster recovery workshop** |
| Machine type | 4-core |

**With the GitHub CLI:**

```bash
gh codespace create -R reggie-k/kubecon-na-2026-most-boring-talk \
  --devcontainer-path .devcontainer/backstage-dr-workshop/devcontainer.json \
  -m standardLinux32gb --idle-timeout 90m
```

It prints the Codespace name. Open it in the browser with `gh codespace code --web -c <name>`, or from <https://github.com/codespaces>. (`standardLinux32gb` is the 4-core machine type. To use your own fork, change `-R`; add `-b <branch>` for a branch.)

A new browser tab opens with the editor. The setup creates the cluster and starts Backstage; it takes a few minutes.

### 3. Keep the tab open, and focus back on the speakers

We will tell you when to start [Part 0 - verifying the setup](docs/00-verify-setup.md). Keep the Codespace tab open: closing it counts towards the idle timeout.

Facilitators: see [docs/facilitator.md](docs/facilitator.md).

# I forgot the portal URL
Run `make ui`. It also checks that Backstage is configured for that URL.

# The portal loads, but shows nothing or every page has an error
The portal URL Backstage is configured for does not match the URL in your browser, so every API call fails. Run `make ui`: if its check fails, run `make setup` (it writes the right URL and restarts Backstage).

If the URL matches, the database may be slow, cut off or gone: run `make status`. After `make db-slow` or `make db-unreachable`, that is the lesson: run `make db-heal`. If the API gives no answer after `make disaster`, that is the lesson too: continue with `make restart-backend` or `make restore`.

# The portal hangs or is very slow
You probably ran `make db-slow` or `make db-unreachable`. Run `make db-heal`: it resets the network between Backstage and Postgres. Nothing is lost.

# The portal does not open inside the editor
Open the **PORTS** tab and select the globe icon next to port 7007 (**Backstage**) to open it in a browser tab. Or Command Palette > **Simple Browser: Show** and paste the URL from `make ui`.

# The guided tour did not start
Command Palette (Cmd/Ctrl+Shift+P) > **CodeTour: Start Tour** > **#1 - Backstage disaster recovery**. If it is not listed, run `make setup`: it writes the tour.

# A dialog offers a "legacy guest token"
Select **Cancel**, reload the portal and select **ENTER** under **Guest**. It appears when you selected **ENTER** while the database was gone.

# "Register Existing Component" fails
Check the URL: `http://catalog-files.backstage.svc.cluster.local/catalog-info.yaml` (http, not https). Or run `make register`, which does the same through the API.

# `make restore` says there is no backup
You skipped `make backup` in Part 1. Without a backup there is nothing to restore: that is a lesson too. Run `make reset` to start the lab over.

# My K8s cluster is unreachable
The Codespace probably stopped and restarted. Run `make setup`.

# My make command is not recognized (No rule to make target)
The Codespace was created with the default configuration, not the Backstage workshop one. If the root folder in the Explorer is `kubecon-na-2026-most-boring-talk`, create a new Codespace and choose the **Backstage disaster recovery workshop** dev container configuration (see the [README](../README.md)).

# I want to start over
`make reset` puts the lab back to the state right after setup, in about 30 seconds. `make teardown` then `make setup` rebuilds the cluster too.

# ckan-matomo-sync-helper-r (dockerized)

Triggers the custom CKAN API action `yukon_matomo_sync_usage_data` in batches,
paginating through all records until the CKAN server reports no more items
remain. This fork packages the script to run unattended in Docker (e.g. on a
server via cron) instead of only interactively in RStudio.

## Installing

Requires [Docker](https://docs.docker.com/get-docker/) (with Compose, bundled
with modern Docker installs) on the machine that will run the sync. No R
installation is needed on the host — R and all packages live inside the
image.

1. Clone this repo onto the server (or wherever it will run):
   ```
   git clone <repo-url> ckan-matomo-sync-helper-r
   cd ckan-matomo-sync-helper-r
   ```
2. Create your `.env` from the template and fill in real values:
   ```
   cp .env.example .env
   ```
   ```
   # .env
   ckan_url="https://open.yukon.ca/"
   ckan_api_token="<a valid CKAN API token, must belong to a sysadmin>"
   ckan_username="<your-ckan-username>"   # optional, only used by test_connection.R
   ```
   `.env` is gitignored — it stays on this machine and is never committed.
   The token must belong to a CKAN sysadmin; the sync action rejects
   non-sysadmin tokens with a 403 before doing anything.
3. Build the image:
   ```
   docker compose build
   ```

### How credentials are handled

`.env` is **never** copied into the Docker image — `.dockerignore` excludes
it from the build context, and the `Dockerfile` has no `COPY` step for it.
Instead, `docker-compose.yml` injects it at container **run** time via
`env_file: .env`, so the values only ever exist as environment variables
inside a running container, not baked into any image layer. If you'd rather
run without Compose, the equivalent is:
```
docker run --rm --env-file .env -v "$(pwd)/log:/app/log" ckan-matomo-sync-helper-r:latest
```

## Testing the connection

Before trusting a real run in a new environment (new server, new `.env`, new
CKAN instance), run the non-destructive connection check. It confirms the
token authenticates, optionally confirms it belongs to a sysadmin (if
`ckan_username` is set), and exercises the sync action itself with
`dry_run = TRUE` (no data is changed):

```
docker compose run --rm sync Rscript test_connection.R
```

A successful run prints the dry-run result, including `total` records and
`has_more`, without updating anything.

## Running the sync

Run the full batch sync (this is the container's default command):

```
docker compose run --rm sync
```

or equivalently:

```
docker compose up
```

This pages through all records (`limit = 20` per request, a 10s pause
between requests to avoid overloading the Matomo instance, capped at 200
iterations as a safety limit) until the server reports no more items. Logs
are written to `log/run_log.csv` and `log/request_log.csv` on the host,
since `docker-compose.yml` mounts `./log` into the container.

## Scheduling with cron

Once a manual `docker compose run --rm sync` succeeds, schedule it on the
server's crontab. Because `docker compose run` always starts a fresh,
short-lived container and exits when the script finishes, it's safe to run
directly from cron without any extra process management.

1. Find the absolute path to the project directory (cron does not run with
   your shell's working directory), e.g. `/opt/ckan-matomo-sync-helper-r`.
2. Edit the crontab for the user that should run the job:
   ```
   crontab -e
   ```
3. Add a line specifying the schedule and using `--project-directory` (or
   `-f`) so cron's working directory doesn't matter. For example, to run
   nightly at 2:00 AM:
   ```cron
   0 2 * * * cd /opt/ckan-matomo-sync-helper-r && /usr/bin/docker compose run --rm sync >> log/cron.log 2>&1
   ```
   Adjust the schedule (`0 2 * * *`) and the `docker` binary path
   (`which docker` on the server) as needed.
4. Confirm the job is scheduled:
   ```
   crontab -l
   ```
5. Check `log/cron.log` (stdout/stderr from cron's invocation) and
   `log/run_log.csv` / `log/request_log.csv` (the script's own structured
   logs) after the first scheduled run to confirm it worked.

Cron jobs run with a minimal environment and no interactive shell, so keep
credentials in `.env` (read via `env_file:` in `docker-compose.yml`) rather
than exporting them in the crontab — nothing beyond the `docker compose`
invocation itself needs to be cron-aware.

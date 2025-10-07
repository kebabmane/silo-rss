# Running Silo with Docker

This guide walks through running Silo in containers using either a single `docker run` command or Docker Compose. It assumes you already have a working Docker installation and, for Compose, the v2 plugin (`docker compose`).

## 1. Generate Required Secrets

Silo expects a Rails credentials master key and a secret key base:

```bash
# From the project root
bin/rails credentials:edit   # creates config/master.key if you don't already have one
bin/rails secret             # copy the generated value for SECRET_KEY_BASE
```

Copy `config/master.key` somewhere safe—you will need the 32-character key inside the file (no newlines).

## 2. Create an Environment File

Make a copy of the provided example and fill in the values:

```bash
cp docker.env.example docker.env
```

Edit `docker.env` and set:

- `RAILS_MASTER_KEY` – paste the key from `config/master.key`
- `SECRET_KEY_BASE` – paste the value from `bin/rails secret`

## 3. Quick Start with Docker Compose (Recommended)

```bash
docker compose --env-file docker.env up --build -d
```

This starts two containers:

- `web` – serves the Rails app on port 3000
- `worker` – runs background jobs via Solid Queue

Persistent volumes `db-data` and `storage-data` keep your SQLite database and uploaded files across restarts.

To apply database migrations the first time you boot, run:

```bash
docker compose --env-file docker.env run --rm web ./bin/rails db:prepare
```

Then visit [http://localhost:3000](http://localhost:3000) to see the Silo landing page. Create an account to start curating feeds.

Stop everything with:

```bash
docker compose down
```

Add `--volumes` if you want to delete the persisted data.

## 4. Single-Container Run

If you prefer a single container, you can build and run the web process only. Background jobs will run inline in the web dyno (suitable for demos, not for production throughput).

```bash
docker build -t silo .
docker run --env-file docker.env -p 3000:3000 --name silo --rm silo
```

The entrypoint automatically runs `bin/rails db:prepare` before booting the server.

## 5. Useful Commands

- View logs: `docker compose logs -f web` (or `worker`)
- Run a one-off task: `docker compose --env-file docker.env run --rm web ./bin/rails runner "puts User.count"`
- Update gems/assets: rebuild the image with `docker compose build`

## 6. Production Notes

- Use `RAILS_ENV=production` (already set) and mount persistent storage.
- Configure your reverse proxy (nginx, Traefik, etc.) to forward HTTPS traffic to port 3000.
- Rotate `SECRET_KEY_BASE` carefully—existing sessions will be invalidated.
- For multi-host deployments, pair this image with Kamal or another orchestrator; the `Dockerfile` is compatible with both.

With these steps you can ship Silo in a containerized environment quickly and repeatably.

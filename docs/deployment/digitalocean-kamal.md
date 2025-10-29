## Deploying to a DigitalOcean Droplet with Kamal

This project ships with a Kamal configuration that targets a single DigitalOcean Droplet. Follow the steps below to provision the infrastructure, configure credentials, and run the first deploy.

### 1. Prerequisites

- DigitalOcean account with API access (for the Container Registry token and Droplet creation).
- A Droplet running Ubuntu 22.04+ (other Debian-based distros are fine) with an SSH key you control.
- Optionally, a domain name pointed at the droplet’s public IP if you want HTTPS via the built-in Traefik proxy.
- A Docker registry (DigitalOcean Container Registry is assumed).
- Your local machine needs Docker, Ruby/Bundler, and the Kamal CLI (`gem install kamal` or `bundle exec kamal`).

### 2. Update Deployment Configuration

Edit `config/deploy.yml` and replace the placeholders:

- `image`: set to your registry namespace (example: `registry.digitalocean.com/my-registry/feed-reader`).
- `servers.web`: set to the SSH target for your droplet (`root@203.0.113.10` or a hostname).
- `proxy.host`: set to the domain that resolves to the droplet, or remove the proxy section if you plan to terminate TLS elsewhere.
- If you use a custom builder droplet for amd64 builds, uncomment and update the `builder.remote` line.

Commit these changes so everyone deploys with the same configuration.

### 3. Prepare Secrets

Kamal reads secrets from `.kamal/secrets`, which now expects you to export values before pushing:

```bash
export RAILS_MASTER_KEY=$(cat config/master.key)
export KAMAL_REGISTRY_PASSWORD="<container-registry-access-token>"
```

Push them to the droplet:

```bash
bundle exec kamal secrets push
```

### 4. Provision Docker on the Droplet

The hook `.kamal/hooks/docker-setup` installs Docker Engine and the compose plugin when you run:

```bash
bundle exec kamal setup
```

This script assumes an Ubuntu/Debian base image with `apt-get`. Adjust the hook if you use a different distribution.

### 5. Push Environment Variables

Set any non-secret production environment variables (for example, Solid Queue concurrency overrides) inside `config/deploy.yml` under `env.clear`. If you need to add or update values later, run:

```bash
bundle exec kamal env push
```

### 6. Build and Deploy

With the registry credentials exported and the configuration updated:

```bash
bundle exec kamal deploy
```

Kamal will build the Docker image locally, push it to the registry, and boot the app on the droplet. The default configuration sets up a persistent Docker volume (`feed_reader_storage`) to hold SQLite databases and Active Storage files.

### 7. Post-Deployment Checklist

- Visit `https://app.your-domain.com` (or the droplet IP) to confirm Traefik issued a certificate and the app boots.
- Run `bundle exec kamal app exec 'bin/rails db:migrate'` if you add new migrations.
- Review logs with `bundle exec kamal logs`.

### 8. Future Changes

- If you add Redis/PostgreSQL, create an accessory in `config/deploy.yml` and provision the service before deploying.
- When scaling beyond a single server, split web/job roles into separate host groups and remove the built-in Traefik proxy in favor of a load balancer or CDN TLS termination.

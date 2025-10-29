# GitHub Actions CI/CD Deployment with Kamal

This guide explains how to set up automated deployments from GitHub to your DigitalOcean VPS using GitHub Actions and Kamal.

## Prerequisites

Before setting up GitHub Actions deployment, you need:

1. **DigitalOcean Droplet** - Ubuntu 22.04+, running
2. **SSH Access** - SSH key pair for the droplet
3. **Docker** - Installed on droplet (via `kamal setup`)
4. **DigitalOcean Container Registry** - Token for pushing images
5. **Domain** - Configured and pointing to your droplet IP
6. **GitHub Repository** - Push access with ability to add secrets

## Step 1: Generate SSH Key for GitHub Actions

If you haven't already, generate an SSH key for GitHub Actions to use:

```bash
# Generate a new SSH key
ssh-keygen -t ed25519 -f ~/.ssh/github-deploy -C "github-actions"

# Display the private key (you'll add this to GitHub Secrets)
cat ~/.ssh/github-deploy

# Display the public key (you'll add this to your droplet)
cat ~/.ssh/github-deploy.pub
```

Add the public key to your droplet:

```bash
# On your droplet, as root
echo "PASTE_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

## Step 2: Add GitHub Secrets

Navigate to your GitHub repository:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add the following secrets:

### Required Secrets

#### `SSH_PRIVATE_KEY`
- **Value**: The full private key from `~/.ssh/github-deploy`
- **Example**:
  ```
  -----BEGIN OPENSSH PRIVATE KEY-----
  b3BlbnNzaC1rZXktdjEA...
  -----END OPENSSH PRIVATE KEY-----
  ```
- **Purpose**: SSH access to your droplet

#### `RAILS_MASTER_KEY`
- **Value**: Content of your `config/master.key` file
- **Command**: `cat config/master.key`
- **Purpose**: Decrypt Rails credentials on deployment

#### `KAMAL_REGISTRY_PASSWORD`
- **Value**: DigitalOcean Container Registry access token
- **How to get**: DigitalOcean Console → API → Tokens → Container Registry
- **Purpose**: Push Docker images to registry

### Optional Secrets (for dynamic configuration)

#### `DROPLET_IP`
- **Value**: Your droplet's IP address
- **Purpose**: Used if not hardcoded in deploy.yml

## Step 3: Update config/deploy.yml

Before deploying, ensure your `config/deploy.yml` is properly configured:

```yaml
# Verify these are set to your actual values:
service: feed_reader
image: registry.digitalocean.com/your-registry/feed-reader

servers:
  web:
    - root@YOUR_DROPLET_IP  # Replace with actual IP

proxy:
  ssl: true
  host: app.your-domain.com  # Replace with your domain

registry:
  server: registry.digitalocean.com
  username: your-registry
  password:
    - KAMAL_REGISTRY_PASSWORD
```

Also update the domain in `.github/workflows/deploy.yml` health check:

```yaml
- name: Health check
  run: |
    curl -f -s -o /dev/null -w "Health check: %{http_code}\n" \
      https://app.your-domain.com/up || true
```

## Step 4: Test the Workflow

### Test Run (No Deployment)

1. Create a test branch:
   ```bash
   git checkout -b test/ci-workflow
   git push origin test/ci-workflow
   ```

2. Go to **GitHub** → **Actions** tab
3. You should see the **CI** workflow running (but not Deploy, since it only runs on `main`)
4. Wait for it to complete - verify all checks pass

### First Production Deployment

1. Commit your changes to a feature branch:
   ```bash
   git checkout -b feature/my-feature
   git add .
   git commit -m "Add my feature"
   git push origin feature/my-feature
   ```

2. Create a Pull Request on GitHub
3. Wait for CI checks to pass
4. Merge the PR to `main`
5. GitHub Actions will automatically:
   - Run security scans
   - Run linting
   - Run tests
   - **Deploy to production** (if all checks pass)

### Monitor Deployment

1. Go to **GitHub** → **Actions** tab
2. Click the **Deploy** workflow run
3. Watch the logs in real-time:
   - Security scans
   - Linting
   - Tests
   - Docker build
   - Kamal deployment
   - Health check

4. Once complete, verify the app is live:
   ```bash
   curl https://app.your-domain.com/up
   ```

## Manual Deployment Trigger

You can also manually trigger a deployment without making code changes:

1. Go to **GitHub** → **Actions** tab
2. Select **Deploy** workflow
3. Click **Run workflow** (at top-right)
4. Select **Branch**: `main`
5. Click **Run workflow**
6. Monitor the deployment logs

This is useful for:
- Retrying a failed deployment
- Deploying hotfixes
- Testing the deployment process

## Deployment Workflow Details

### Workflow: CI (Runs on every push)

**Triggers**: Every push and pull request

**Jobs**:
1. **security_scan** - Run Brakeman security analysis
2. **lint** - Check code style with RuboCop
3. **test** - Run test suite

**Artifacts**:
- Screenshots from failed system tests (stored for 90 days)

### Workflow: Deploy (Runs after CI passes on main branch)

**Triggers**: Push to `main` branch (after all CI jobs pass)

**Jobs**:
1. **security_scan** (runs again to be sure)
2. **lint** (runs again to be sure)
3. **test** (runs again to be sure)
4. **deploy**:
   - Sets up Docker Buildx with caching
   - Configures SSH for server access
   - Installs Kamal gem
   - Builds and pushes Docker image
   - Deploys with zero-downtime rolling updates
   - Runs post-deployment health check

**Secrets used**:
- `RAILS_MASTER_KEY` - Rails credentials
- `KAMAL_REGISTRY_PASSWORD` - Docker registry access
- `SSH_PRIVATE_KEY` - Server SSH access

## Viewing Deployment Logs

### GitHub Actions Logs

1. Go to **GitHub** → **Actions** tab
2. Click the **Deploy** workflow run
3. Click **deploy** job
4. Scroll through logs to see:
   - Docker build progress
   - Docker push to registry
   - SSH connection to droplet
   - Kamal deployment commands
   - Container startup
   - Health check result

### Server Logs

View logs directly on the droplet:

```bash
# SSH into your droplet
ssh root@YOUR_DROPLET_IP

# View Kamal deployment logs
cd /var/kamal
tail -f logs/app.log

# Or use Kamal command
kamal logs -f

# View Docker container logs
docker logs feed_reader
```

## Rollback on Failed Deployment

If a deployment fails and you need to rollback:

### Option 1: Deploy Previous Commit (via GitHub)

```bash
# Push the commit you want to revert to
git revert HEAD
git push origin main

# Or revert the merge commit
git reset --hard HEAD~1
git push origin main --force-with-lease

# GitHub Actions will automatically deploy the previous version
```

### Option 2: Rollback via Kamal (Immediate)

On your droplet:

```bash
# SSH into droplet
ssh root@YOUR_DROPLET_IP

# View deployment history
kamal app details

# Redeploy to previous version
kamal app boot  # Start previous container version
```

### Option 3: Manual Kamal Deploy

```bash
# From your local machine
export RAILS_MASTER_KEY=$(cat config/master.key)
export KAMAL_REGISTRY_PASSWORD="your-token"

kamal deploy --version=PREVIOUS_VERSION
```

## Troubleshooting

### Deployment fails with "SSH: connection refused"

**Cause**: SSH key not added to droplet or SSH not configured properly

**Fix**:
1. Verify SSH key is on droplet: `cat ~/.ssh/authorized_keys`
2. Verify SSH port (default 22): `sudo ss -tlnp | grep 22`
3. Update `SSH_PRIVATE_KEY` secret with correct key

### Docker push fails with "authentication required"

**Cause**: `KAMAL_REGISTRY_PASSWORD` is invalid or expired

**Fix**:
1. Generate new DigitalOcean API token
2. Update `KAMAL_REGISTRY_PASSWORD` secret
3. Retry deployment

### Health check fails after deployment

**Cause**: App not responding or domain misconfigured

**Fix**:
1. Check app is running: `docker ps` on droplet
2. Check logs: `kamal logs`
3. Verify domain DNS points to droplet IP
4. Wait 30 seconds for app to fully start
5. Check SSL certificate: `curl -vI https://app.your-domain.com`

### Tests fail in GitHub Actions but pass locally

**Cause**: Environment variable differences or database state

**Fix**:
1. Check GitHub Actions logs for specific error
2. Compare local .env.test with CI environment
3. Ensure database is reset: `bin/rails db:test:prepare`
4. Check for flaky tests (run multiple times locally)

### Docker build timeout

**Cause**: GitHub Actions runners sometimes have slow internet

**Fix**:
1. Docker layer caching should help (already configured)
2. Check runner logs for network issues
3. Manually trigger deployment again
4. Consider pushing to a private Docker registry first

### Kamal command not found

**Cause**: Kamal gem not installed in GitHub Actions environment

**Fix**:
1. Ensure `bundler-cache: true` in setup-ruby step (already done)
2. Verify Gemfile has `gem 'kamal'`
3. Check Gemfile.lock is committed

## Advanced Configuration

### Deploy to Staging First

Create `.github/workflows/deploy-staging.yml` that deploys to a staging environment:

```yaml
on:
  push:
    branches: [ develop ]
```

Configure a separate Kamal config for staging:
- `config/deploy-staging.yml`
- Different domain/server
- Same Docker registry (different tag)

### Notify on Deployment

Add Slack/Discord notifications:

```yaml
- name: Notify Slack
  if: always()
  run: |
    curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
      -d '{"text": "Deployment: ${{ job.status }}"}'
```

### Database Backups Before Deploy

Add pre-deployment backup:

```yaml
- name: Backup database
  run: |
    bundle exec kamal app exec 'bin/rails db:migrate:backup'
```

## Useful Commands

### Local Testing

```bash
# Test deployment locally (without actually deploying)
kamal deploy --dry-run

# View what would be deployed
kamal preview

# SSH to production server
kamal shell
```

### View Deployment History

```bash
# On droplet
kamal app details

# In GitHub Actions logs
# Go to Actions → Deploy workflow → deploy job → Scroll to Kamal output
```

## Security Notes

1. **Never commit secrets** to your repository
2. **Rotate SSH keys** periodically
3. **Restrict GitHub repository** access to team members only
4. **Use branch protection** rules to require CI passes before merging
5. **Review deployment logs** regularly for unauthorized changes
6. **Enable 2FA** on your GitHub account

## Getting Help

If you encounter issues:

1. Check **GitHub Actions logs** first (detailed error messages)
2. Check **Kamal documentation**: https://kamal-deploy.org
3. Check **your droplet logs**: `ssh root@IP` then `kamal logs`
4. Review this guide's troubleshooting section above
5. Check GitHub Issues for similar problems

## Next Steps

1. ✅ Add SSH secrets to GitHub
2. ✅ Add RAILS_MASTER_KEY secret
3. ✅ Add KAMAL_REGISTRY_PASSWORD secret
4. ✅ Update config/deploy.yml with your values
5. ✅ Commit changes and push to main
6. ✅ Watch GitHub Actions deploy your app!

Good luck with your deployment! 🚀

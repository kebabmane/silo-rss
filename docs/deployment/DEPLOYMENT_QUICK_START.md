# Deploy to DigitalOcean with Kamal & GitHub Actions - Quick Start

This guide walks you through your **first deployment** and setting up the **automated deployment pipeline**.

## 🎯 What You'll Do

1. Prepare your droplet (5 min)
2. Generate SSH key for GitHub Actions (5 min)
3. Add GitHub Secrets (10 min)
4. Update deployment config (10 min)
5. Deploy your app (10 min)
6. Set up automated pipeline (done!)

**Total time: ~40 minutes**

---

## Step 1: Prepare Your DigitalOcean Droplet

### Get Your Droplet IP

1. Go to [DigitalOcean Console](https://cloud.digitalocean.com)
2. Click **Droplets** → Find your droplet
3. Copy the IPv4 address

**Your Droplet IP:** `_____________________`

### Verify SSH Access

Test that you can SSH into your droplet:

```bash
ssh root@YOUR_DROPLET_IP
```

You should see the welcome message. Type `exit` to disconnect.

If SSH fails, ensure:
- Your SSH key is added to the droplet
- You're using the correct IP
- Droplet is running

---

## Step 2: Generate SSH Key for GitHub Actions

GitHub Actions needs an SSH key to deploy to your droplet. We'll create a dedicated key just for CI/CD.

### Generate the Key

On your **local machine**:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/github-deploy -C "github-actions"
```

Press Enter when prompted for passphrase (leave empty).

You now have:
- **Private key:** `~/.ssh/github-deploy` (keep secret!)
- **Public key:** `~/.ssh/github-deploy.pub`

### Add Public Key to Your Droplet

```bash
# Copy the public key content
cat ~/.ssh/github-deploy.pub
```

Copy the output, then:

```bash
# Add it to your droplet's authorized_keys
ssh root@YOUR_DROPLET_IP 'echo "PASTE_THE_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys'
```

### Test It Works

```bash
ssh -i ~/.ssh/github-deploy root@YOUR_DROPLET_IP
```

You should connect without a password prompt. Type `exit` when done.

---

## Step 3: Collect Your Secrets & Values

Gather these values - you'll need them for GitHub:

### 🔑 SSH Private Key

```bash
# Copy the entire output (including BEGIN/END lines)
cat ~/.ssh/github-deploy
```

**Save this for step 4.**

### 🔑 Rails Master Key

```bash
cat config/master.key
```

**Copy this value.**

### 🔑 DigitalOcean Registry Token

1. Go to [DigitalOcean Console](https://cloud.digitalocean.com)
2. Click **API** (top-right menu)
3. Click **Tokens/Keys** tab
4. Click **Generate New Token**
   - Name: `Silo CI/CD`
   - Expiration: 90 days (or longer)
   - Scopes: Check "Container Registry"
5. Copy the token immediately (you can't see it again!)

**Save this value.**

### 📍 Your Droplet Details

- **Droplet IP:** `_____________________`
- **Domain:** `_____________________` (e.g., `silo-reader.com` or `app.silo-reader.com`)
- **DigitalOcean Registry Name:** `_____________________` (e.g., `my-registry`)

---

## Step 4: Update Kamal Configuration

Your deployment config has placeholders. Time to fill them in!

### Edit `config/deploy.yml`

Open the file and find these lines:

```yaml
# Line 5 - Update image registry path
image: registry.digitalocean.com/your-registry/feed-reader
↓
image: registry.digitalocean.com/YOUR_REGISTRY_NAME/feed-reader

# Line 10 - Update droplet IP
servers:
  web:
    - root@YOUR_DROPLET_IP
↓
servers:
  web:
    - root@YOUR_DROPLET_IP_ADDRESS

# Line 22 - Update your domain
proxy:
  ssl: true
  host: app.your-domain.com
↓
proxy:
  ssl: true
  host: app.your-domain.com  (use YOUR actual domain)

# Line 28 - Update registry username
registry:
  username: your-registry
↓
registry:
  username: YOUR_REGISTRY_NAME
```

### Example (if your details are):
- Domain: `silo.example.com`
- Droplet IP: `192.0.2.1`
- Registry: `my-silo-registry`

Your file should look like:

```yaml
image: registry.digitalocean.com/my-silo-registry/feed-reader

servers:
  web:
    - root@192.0.2.1

proxy:
  ssl: true
  host: silo.example.com

registry:
  server: registry.digitalocean.com
  username: my-silo-registry
```

### Verify Your Changes

```bash
grep -E "YOUR_DROPLET_IP|your-domain|your-registry" config/deploy.yml
```

Should show no results (all placeholders replaced).

---

## Step 5: Add GitHub Secrets

Now GitHub Actions can deploy to your droplet!

### Go to GitHub Secrets

1. Go to [github.com/kebabmane/silo-rss](https://github.com/kebabmane/silo-rss)
2. Click **Settings** (top navigation)
3. Click **Secrets and variables** → **Actions** (left sidebar)
4. Click **New repository secret** (green button)

### Add Three Secrets

#### Secret #1: SSH_PRIVATE_KEY

- **Name:** `SSH_PRIVATE_KEY`
- **Value:** Paste your **entire** private key (from step 3)
  - Include the `-----BEGIN OPENSSH PRIVATE KEY-----` line
  - Include the `-----END OPENSSH PRIVATE KEY-----` line
  - Should be ~400+ characters
- Click **Add secret**

#### Secret #2: RAILS_MASTER_KEY

- **Name:** `RAILS_MASTER_KEY`
- **Value:** Your rails master key (from step 3)
  - Just the key, no extra text
  - Should be ~32 characters
- Click **Add secret**

#### Secret #3: KAMAL_REGISTRY_PASSWORD

- **Name:** `KAMAL_REGISTRY_PASSWORD`
- **Value:** Your DigitalOcean registry token (from step 3)
  - Should be ~64 characters
- Click **Add secret**

### Verify

You should now see three secrets listed:
- ✅ `SSH_PRIVATE_KEY`
- ✅ `RAILS_MASTER_KEY`
- ✅ `KAMAL_REGISTRY_PASSWORD`

---

## Step 6: Set Up DNS (If Using Custom Domain)

If you're using a custom domain (recommended for production):

1. Go to your domain registrar (Namecheap, GoDaddy, etc.)
2. Find DNS settings
3. Add an A record:
   - **Name:** `@` (for root) or `app` (for subdomain)
   - **Type:** `A`
   - **Value:** Your droplet's IP address
4. Wait 5-30 minutes for DNS to propagate

Test DNS:
```bash
nslookup silo.example.com
```

---

## Step 7: First Manual Deployment (Recommended)

Before trusting the automated pipeline, let's do one manual test.

### Deploy Locally

From your local machine, in your Silo directory:

```bash
# Export secrets (GitHub Actions does this automatically)
export RAILS_MASTER_KEY=$(cat config/master.key)
export KAMAL_REGISTRY_PASSWORD="your-registry-token"

# First time: sets up Docker on droplet
bundle exec kamal setup

# Deploy your app
bundle exec kamal deploy
```

This will:
1. Build Docker image locally
2. Push to DigitalOcean registry
3. SSH to droplet
4. Start containers
5. Run migrations
6. Set up SSL

**Takes 3-5 minutes.** Watch the output for any errors.

### Verify Deployment

Once it finishes:

```bash
# Check if it's running
curl https://silo.example.com/up

# Should return "OK" with a 200 status code
```

If using IP directly (no domain):
```bash
curl -k https://YOUR_DROPLET_IP/up
```

View logs on your droplet:
```bash
# SSH to droplet
ssh root@YOUR_DROPLET_IP

# View app logs
kamal logs -f

# View container status
docker ps

# Type Ctrl+C to exit logs
```

---

## Step 8: Set Up Automated Deployment Pipeline

Now GitHub Actions will automatically deploy when you push to `main`!

### How It Works

```
You push code to GitHub
         ↓
GitHub Actions:
  - Runs security scan
  - Runs linting
  - Runs tests
         ↓
     All pass?
         ↓
   (if all pass)
         ↓
GitHub Actions:
  - Builds Docker image
  - Pushes to registry
  - SSHs to droplet
  - Deploys with Kamal
  - Health check
         ↓
   App is live!
```

### Test the Pipeline

Make a small change to trigger it:

```bash
# Create a test branch
git checkout -b test/deployment

# Make a small change (e.g., update README)
echo "# Silo - Deployed $(date)" >> README.md

# Commit and push
git add README.md
git commit -m "Test deployment pipeline"
git push origin test/deployment
```

### Watch GitHub Actions

1. Go to your GitHub repo
2. Click **Actions** tab
3. You should see **CI** workflow running
4. Wait for it to complete (should pass ✅)
5. This confirms your setup works!

Now create a Pull Request and merge to `main`:

```bash
# Or go to GitHub UI and create PR, then merge
git checkout main
git pull origin main
git merge test/deployment
git push origin main
```

### Watch Deployment

1. Go to **Actions** tab
2. Click the **Deploy** workflow
3. Watch the deployment happen live!
4. Once complete, verify:

```bash
curl https://silo.example.com
```

---

## Step 9: Automated Deployments Going Forward

From now on, every time you push to `main`, your app automatically deploys!

### Your Workflow

```bash
# 1. Create a feature branch
git checkout -b feature/new-feature

# 2. Make changes
echo "New feature code" >> app/models/something.rb

# 3. Commit and push
git add .
git commit -m "Add new feature"
git push origin feature/new-feature

# 4. Create Pull Request on GitHub
# (or do it via GitHub UI)

# 5. Merge to main when ready
git checkout main
git pull origin main
git merge feature/new-feature
git push origin main

# 6. GitHub Actions automatically deploys!
# (watch the Actions tab)
```

---

## Troubleshooting

### Deployment Fails with "SSH: connection refused"

**Cause:** SSH key not on droplet or permission issues

**Fix:**
```bash
# Verify SSH works
ssh -i ~/.ssh/github-deploy root@YOUR_DROPLET_IP

# Re-add public key if needed
ssh-keyscan YOUR_DROPLET_IP >> ~/.ssh/known_hosts
```

### Docker Push Fails with "authentication required"

**Cause:** `KAMAL_REGISTRY_PASSWORD` secret is wrong or expired

**Fix:**
1. Go to DigitalOcean → API → Tokens
2. Generate a new token
3. Update the `KAMAL_REGISTRY_PASSWORD` secret in GitHub

### Health Check Fails

**Cause:** App not responding or domain not configured

**Fix:**
```bash
# SSH to droplet
ssh root@YOUR_DROPLET_IP

# Check container is running
docker ps

# Check logs
docker logs feed_reader

# Verify DNS is set up correctly
nslookup silo.example.com
```

### Tests Fail in GitHub Actions

**Cause:** Environment difference or code issue

**Fix:**
1. Check GitHub Actions logs for specific error
2. Run tests locally: `bin/rails test`
3. Fix the issue and push again

---

## Managing Your Deployment

### View Logs

```bash
# SSH to droplet
ssh root@YOUR_DROPLET_IP

# View app logs (live)
kamal logs -f

# View app logs (last 100 lines)
kamal logs | tail -100

# View specific service logs
docker logs feed_reader

# Exit log viewer: Ctrl+C
```

### Restart App

```bash
ssh root@YOUR_DROPLET_IP

# Restart the app container
kamal app restart

# Stop the app
kamal app stop

# Start the app
kamal app boot
```

### Run Database Commands

```bash
# SSH to droplet
ssh root@YOUR_DROPLET_IP

# Run migrations
kamal app exec 'bin/rails db:migrate'

# Console access
kamal console
```

### Rollback to Previous Version

```bash
# If a bad deployment happens:

# Option 1: Revert the commit (automatic deploy)
git revert <commit-hash>
git push origin main
# GitHub Actions will deploy the reverted code

# Option 2: Manual rollback (immediate)
ssh root@YOUR_DROPLET_IP
kamal app boot  # Restarts previous version
```

---

## Monitoring Your App

### GitHub Actions Dashboard

Watch deployments in real-time:
- Go to Actions tab
- Click on **Deploy** workflow runs
- See detailed logs of each step

### Application Health

```bash
# Quick health check
curl https://silo.example.com/up

# Should return "OK" with status 200
```

### Server Status

```bash
ssh root@YOUR_DROPLET_IP

# Check disk space
df -h

# Check memory usage
free -h

# Check running containers
docker ps
```

---

## Next Steps

### Recommended Post-Deployment

1. **Set up monitoring** - Use UptimeRobot, Pingdom, or similar
2. **Set up error tracking** - Add Sentry for error monitoring
3. **Configure backups** - Set up SQLite backups
4. **Set up CORS** - Restrict API access to your domains
5. **Enable admin users** - Set up admin account for management

See other deployment guides for these advanced topics.

---

## Quick Reference

### Commands

```bash
# Deploy manually
bundle exec kamal deploy

# View status
bundle exec kamal app details

# View logs
bundle exec kamal logs -f

# SSH to droplet
ssh root@YOUR_DROPLET_IP

# Console on droplet
kamal console

# Restart app
kamal app restart
```

### Common URLs

- **App:** `https://silo.example.com`
- **Health check:** `https://silo.example.com/up`
- **Admin:** `https://silo.example.com/admin`
- **API:** `https://silo.example.com/api/v1/`

### Important Files

- **Deployment config:** `config/deploy.yml`
- **Deployment workflow:** `.github/workflows/deploy.yml`
- **Environment secrets:** GitHub repo → Settings → Secrets

---

**You're done!** Your app is now:
- ✅ Deployed to DigitalOcean
- ✅ Accessible via HTTPS
- ✅ Automatically updated on every push to main
- ✅ Zero-downtime deployments

**Congratulations!** 🚀

---

**Questions?** Check the detailed guides:
- [GitHub Actions Complete Guide](./github-actions-kamal.md)
- [DigitalOcean Setup Guide](./digitalocean-kamal.md)
- [Setup Checklist](./SETUP_CHECKLIST.md)

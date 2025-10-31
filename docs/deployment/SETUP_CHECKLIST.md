# GitHub Actions + Kamal Deployment Setup Checklist

Follow this checklist to set up automated deployments from GitHub to your VPS.

## ⚡ Quick Start

**New to this?** Start with: [`DEPLOYMENT_QUICK_START.md`](./DEPLOYMENT_QUICK_START.md)

That guide walks you through everything step-by-step. Come back here for reference.

---

## 1. DigitalOcean VPS Setup (If not already done)

- [ ] Create Ubuntu 22.04+ droplet on DigitalOcean
- [ ] Note the droplet IP address: `_________________`
- [ ] Add your SSH public key to droplet
- [ ] Test SSH access: `ssh root@YOUR_DROPLET_IP`
- [ ] Create DigitalOcean Container Registry
- [ ] Note registry name: `_________________`

## 2. Domain & DNS Setup

- [ ] Register or transfer domain
- [ ] Note your domain: `_________________`
- [ ] Add A record pointing to droplet IP: `YOUR_DROPLET_IP`
- [ ] Test DNS resolution: `nslookup app.your-domain.com`
- [ ] Wait for DNS to propagate (5-30 minutes)

## 3. Generate SSH Key for GitHub Actions

Run on your local machine:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/github-deploy -C "github-actions"
```

Then add public key to droplet:

```bash
ssh root@YOUR_DROPLET_IP 'echo "PASTE_PUBLIC_KEY_CONTENT_HERE" >> ~/.ssh/authorized_keys'
```

- [ ] SSH key pair generated
- [ ] Public key added to droplet authorized_keys
- [ ] Test: `ssh -i ~/.ssh/github-deploy root@YOUR_DROPLET_IP`

## 4. Get Required Secrets & Values

Collect these values - you'll need them for GitHub Secrets:

### SSH Private Key
```bash
cat ~/.ssh/github-deploy
```
- [ ] Copy full SSH private key (including BEGIN/END lines)

### Rails Master Key
```bash
cat config/master.key
```
- [ ] Copy Rails master key value: `_________________`

### DigitalOcean Registry Token
1. Go to DigitalOcean Console
2. API → Tokens → Generate New Token
3. Copy the token
- [ ] DigitalOcean registry token: `_________________`

### Droplet IP & Domain
- [ ] Droplet IP: `_________________`
- [ ] Domain: `_________________`
- [ ] Registry name: `_________________`

## 5. Update Local Configuration Files

### config/deploy.yml
Update these values:

```yaml
image: registry.digitalocean.com/YOUR-REGISTRY/feed-reader
servers:
  web:
    - root@YOUR_DROPLET_IP
proxy:
  host: app.your-domain.com
registry:
  username: YOUR-REGISTRY
```

- [ ] Updated image registry path
- [ ] Updated droplet IP
- [ ] Updated domain name
- [ ] Updated registry username

### .github/workflows/deploy.yml
Update the health check domain:

```yaml
- name: Health check
  run: |
    curl -f -s -o /dev/null -w "Health check: %{http_code}\n" \
      https://app.your-domain.com/up || true
```

- [ ] Updated health check domain

## 6. Add GitHub Repository Secrets

1. Go to **GitHub** → Your repo → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret** for each:

### SSH_PRIVATE_KEY
- [ ] Add secret `SSH_PRIVATE_KEY`
  - Value: Full contents of `~/.ssh/github-deploy` (with BEGIN/END lines)

### RAILS_MASTER_KEY
- [ ] Add secret `RAILS_MASTER_KEY`
  - Value: Contents of `config/master.key`

### KAMAL_REGISTRY_PASSWORD
- [ ] Add secret `KAMAL_REGISTRY_PASSWORD`
  - Value: DigitalOcean registry access token

### Optional: DROPLET_IP & DOCKER_REGISTRY
- [ ] Add secret `DROPLET_IP` (if using dynamic config)
- [ ] Add secret `DOCKER_REGISTRY` (if needed)

## 7. Verify Files Are In Place

- [ ] `.github/workflows/ci.yml` exists (tests/security/lint)
- [ ] `.github/workflows/deploy.yml` exists (deployment workflow)
- [ ] `docs/deployment/github-actions-kamal.md` exists (documentation)
- [ ] `config/deploy.yml` is updated with your values
- [ ] All secrets added to GitHub

## 8. First Deployment

### Step 1: Commit changes
```bash
git add config/deploy.yml .github/workflows/deploy.yml docs/deployment/
git commit -m "Add GitHub Actions deployment workflow"
```

- [ ] Changes committed locally

### Step 2: Push to test branch (optional, to verify CI works)
```bash
git push origin -u feature/add-ci-deployment
```

- [ ] Wait for GitHub Actions to run
- [ ] Verify CI passes (security scan, lint, tests)
- [ ] Create a Pull Request
- [ ] Verify CI passes on PR

### Step 3: Merge to main (triggers deployment)
```bash
# Via GitHub UI: Click "Merge pull request"
# Or via CLI:
git checkout main
git merge feature/add-ci-deployment
git push origin main
```

- [ ] Merged to main branch
- [ ] GitHub Actions Deploy workflow started

### Step 4: Monitor deployment
1. Go to **GitHub** → **Actions** tab
2. Click the **Deploy** workflow run
3. Wait for all jobs to complete:
   - security_scan ✅
   - lint ✅
   - test ✅
   - deploy ✅

- [ ] All CI checks passed
- [ ] Deploy job completed
- [ ] Health check passed

### Step 5: Verify app is live
```bash
curl https://app.your-domain.com
curl https://app.your-domain.com/up  # Health check
```

- [ ] App responds on domain
- [ ] Health check returns OK
- [ ] No errors in browser or logs

## 9. Post-Deployment Tasks

### Check Droplet

```bash
ssh root@YOUR_DROPLET_IP

# View running containers
docker ps

# View app logs
kamal logs -f

# Test app locally on droplet
curl http://localhost:3000/up
```

- [ ] SSH into droplet succeeds
- [ ] Container is running
- [ ] Logs show no errors
- [ ] Health check passes

### Verify Features

1. Visit `https://app.your-domain.com`
   - [ ] Landing page loads
   - [ ] Styling looks correct
   - [ ] No errors in console

2. Test authentication
   - [ ] Sign up works
   - [ ] Sign in works
   - [ ] Logout works

3. Test core features
   - [ ] Add a feed
   - [ ] View articles
   - [ ] Mark as read
   - [ ] Admin panel accessible

## 10. Ongoing Maintenance

### For Each Deployment

1. Make changes on a feature branch
2. Push to GitHub
3. Wait for CI to pass
4. Create Pull Request
5. Review and merge to main
6. GitHub Actions automatically deploys

### Monitor Health

- [ ] Check GitHub Actions logs weekly
- [ ] Monitor droplet via DigitalOcean console
- [ ] Review app logs: `kamal logs`
- [ ] Monitor uptime (setup monitoring service)

### Updates & Maintenance

- [ ] Update Gemfile dependencies regularly
- [ ] Run `bin/brakeman` to check for security issues
- [ ] Update DigitalOcean credentials if they expire
- [ ] Backup database regularly

## 11. Emergency Rollback

If deployment fails or you need to rollback:

### Option 1: Revert commit (safest)
```bash
git revert <commit-hash>
git push origin main
# GitHub Actions will deploy the reverted version
```

### Option 2: Kamal rollback (immediate)
```bash
# SSH to droplet
ssh root@YOUR_DROPLET_IP

# View version history
kamal app details

# Redeploy previous version
kamal app boot
```

- [ ] Understand rollback process
- [ ] Know how to access droplet
- [ ] Know Kamal commands

## Support & Documentation

- [ ] Read `docs/deployment/github-actions-kamal.md` for detailed guide
- [ ] Read `docs/deployment/digitalocean-kamal.md` for original setup
- [ ] Bookmark Kamal docs: https://kamal-deploy.org
- [ ] Bookmark DigitalOcean docs: https://docs.digitalocean.com

## Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| SSH key rejected | Verify key on droplet: `cat ~/.ssh/authorized_keys` |
| Docker push fails | Check `KAMAL_REGISTRY_PASSWORD` secret |
| Health check fails | Wait 30s, check `kamal logs`, verify domain DNS |
| Tests fail in CI | Check GitHub Actions logs, run locally |
| Deployment hangs | Check server resources with `htop` on droplet |
| App not responding | SSH to droplet, check `docker ps` and `kamal logs` |

---

**Congratulations!** You now have automated deployments set up. Every push to `main` will automatically deploy your app! 🚀

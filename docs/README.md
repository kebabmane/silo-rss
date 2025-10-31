# Silo Documentation

Welcome to the Silo documentation. Here you'll find guides for development, deployment, API usage, and more.

## 📚 Documentation Structure

### 🚀 [Deployment](./deployment/)
Complete guides for deploying Silo to production.

- **[GitHub Actions + Kamal Setup](./deployment/github-actions-kamal.md)** - Automated CI/CD deployment pipeline with GitHub Actions
- **[Setup Checklist](./deployment/SETUP_CHECKLIST.md)** - Interactive checklist for first-time deployment
- **[GitHub Actions Quick Reference](./deployment/GITHUB_ACTIONS_SETUP_SUMMARY.md)** - Quick reference for GitHub Actions setup
- **[DigitalOcean + Kamal Guide](./deployment/digitalocean-kamal.md)** - Initial DigitalOcean VPS setup with Kamal

### 🔌 [API Documentation](./api/)
Complete REST API documentation for building mobile and web clients.

- **[API Documentation](./api/API_DOCUMENTATION.md)** - Complete REST API reference with examples
- **[Mobile API Readiness](./api/MOBILE_API_READINESS.md)** - Mobile app integration guide and best practices

### 👨‍💻 [Development](./development/)
Guides for developing Silo and contributing to the project.

- **[Claude Code Agent Workflow](./development/CLAUDE.md)** - Best practices for using Claude Code agents on this project

### 🐳 [Docker](./docker.md)
Docker and Docker Compose setup for running Silo locally or in production.

---

## 🎯 Quick Links by Use Case

### I want to...

**Deploy to a VPS**
1. Start with: [`deployment/SETUP_CHECKLIST.md`](deployment/SETUP_CHECKLIST.md)
2. Then read: [`deployment/github-actions-kamal.md`](deployment/github-actions-kamal.md)
3. Reference: [`deployment/digitalocean-kamal.md`](deployment/digitalocean-kamal.md)

**Build a mobile app**
1. Read: [`api/API_DOCUMENTATION.md`](api/API_DOCUMENTATION.md)
2. Check: [`api/MOBILE_API_READINESS.md`](api/MOBILE_API_READINESS.md)

**Run Silo with Docker**
- Read: [`docker.md`](docker.md)

**Develop Silo with Claude Code**
- Read: [`development/CLAUDE.md`](development/CLAUDE.md)

---

## 📋 File Organization

```
docs/
├── README.md                          ← You are here
├── docker.md                          ← Docker quick start
│
├── api/
│   ├── API_DOCUMENTATION.md          ← Complete REST API reference
│   └── MOBILE_API_READINESS.md       ← Mobile app integration guide
│
├── deployment/
│   ├── SETUP_CHECKLIST.md            ← Interactive first-time setup
│   ├── GITHUB_ACTIONS_SETUP_SUMMARY.md ← Quick reference
│   ├── github-actions-kamal.md       ← Detailed GitHub Actions guide
│   └── digitalocean-kamal.md         ← DigitalOcean initial setup
│
└── development/
    └── CLAUDE.md                      ← Claude Code workflow guide
```

---

## 🚀 Getting Started

### New to Silo?
Start with the [main README.md](../README.md) in the root directory.

### Want to deploy?
Jump to [Deployment Quick Reference](./deployment/SETUP_CHECKLIST.md).

### Building a mobile app?
Check out the [API Documentation](./api/API_DOCUMENTATION.md).

### Running locally?
Read the [main README.md](../README.md) for local development setup.

### Using Docker?
See [docker.md](./docker.md).

---

## 🔗 Related Resources

- **Main README**: [`../README.md`](../README.md) - Features, quick start, usage guide
- **GitHub Repository**: https://github.com/kebabmane/silo-rss
- **GitHub Issues**: Report bugs or request features
- **Rails Documentation**: https://guides.rubyonrails.org/
- **Tailwind CSS**: https://tailwindcss.com/
- **Kamal**: https://kamal-deploy.org/

---

## 📞 Need Help?

1. Check the relevant documentation guide above
2. Search GitHub Issues for similar questions
3. Review the troubleshooting sections in specific guides
4. Create a GitHub Issue with:
   - What you tried
   - Error message (if any)
   - Your environment (Ruby/Rails version, OS)
   - Steps to reproduce

---

**Last Updated**: October 30, 2024

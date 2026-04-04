# Silo

Silo is your personal internet inbox: a modern, self-hosted RSS/Atom feed reader built with Rails 8. Curate the sites you care about, catch up with daily briefs, and read in a calm three-pane interface with dark mode, keyboard shortcuts, and powerful feed management tools.

## Features

### Core Functionality
- **Feed Management**
  - Auto-discovery: Paste any website URL, we'll find the RSS/Atom feed
  - Direct feed URL support
  - Organize feeds into categories/folders
  - OPML import/export for easy migration

- **Reading Experience**
  - Three-pane Turbo-powered interface (folders → articles → content)
  - Full article content extraction
  - Read/unread tracking per user
  - Star/favorite articles
  - Archive articles
  - Clean, distraction-free reading view

- **Advanced Features**
  - Full-text search across all articles
  - Filter by feed, category, date, read status
  - Keyboard shortcuts for power users
  - Dark mode with theme persistence
  - Auto-refresh feeds every 15 minutes

### Technical Stack
- **Rails 8** with Hotwire (Turbo + Stimulus)
- **SQLite** for database (production-ready with Rails 8)
- **Tailwind CSS** for styling
- **Solid Queue** for background jobs
- **Feedjira** for RSS/Atom parsing
- **Docker** ready for easy deployment

## Requirements

- Ruby 3.3.0
- Rails 8.0+
- SQLite 3
- Node.js (for asset compilation)

## Quick Start

### Local Development

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd feed_reader
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Setup database**
   ```bash
   bin/rails db:migrate
   bin/rails db:migrate SCHEMA=db/queue_schema.rb
   ```

4. **Start the application**
   ```bash
   bin/dev
   ```

5. **Visit** [http://localhost:3000](http://localhost:3000)

6. **Create your account** and start adding feeds!

### Docker Deployment

See [`docs/docker.md`](docs/docker.md) for a complete walkthrough of running Silo with Docker or Docker Compose, including environment configuration, database migrations, and background workers.

## Usage Guide

### Adding Feeds

1. Click **"Add Feed"** in the navigation
2. Enter either:
   - A website URL (e.g., `https://example.com`) - we'll auto-discover the feed
   - A direct RSS/Atom feed URL
3. Assign a category (e.g., "Tech", "News", "Blogs")
4. Optionally set a custom name
5. Click **"Add to My Feeds"**

### Keyboard Shortcuts

Press `?` to see all shortcuts:

- `j` - Next article
- `k` - Previous article
- `m` - Mark as read/unread
- `s` - Star/unstar article
- `a` - Archive article
- `v` - View original article
- `?` - Show help

## API & CLI

Silo provides both a REST API and a command-line interface for integration with mobile apps, automation scripts, and AI agents.

### REST API

The API is available at `/api/v1` and provides full access to feeds, articles, and user data.

**Key Features:**
- Bearer token authentication
- Delta sync for mobile offline support (`/api/v1/sync`)
- Cursor-based pagination for efficient list loading
- Full-text search across articles
- Batch operations for bulk updates
- CLI tokens (non-expiring) for automation

**Quick Example:**
```bash
# Login
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password"}'

# List unread articles
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/v1/articles?filter=unread&limit=20"

# Delta sync for mobile
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:3000/api/v1/sync?since=2025-01-01T00:00:00Z"
```

See [docs/api/API_DOCUMENTATION.md](docs/api/API_DOCUMENTATION.md) for complete API reference and [openapi.yaml](openapi.yaml) for OpenAPI specification.

### CLI Tool

The `silo-cli` gem provides command-line access to your feeds.

**Installation:**
```bash
cd cli
bundle install
```

**Usage:**
```bash
# Authenticate
silo auth login

# List feeds with unread counts
silo feeds list

# Add a new feed
silo feeds add https://example.com/blog --category "Technology"

# Read articles
silo articles list --filter=unread --limit=10
silo articles show 123

# Mark as read
silo articles read 123
```

See [cli/README.md](cli/README.md) for detailed CLI documentation.

### AI Agent Integration (MCP)

Silo includes an MCP (Model Context Protocol) server for AI agents like Claude:

```bash
# Start MCP server
silo mcp
```

AI agents can then:
- List feeds and unread counts
- Search articles
- Mark articles as read
- Subscribe to new feeds

See [SKILL.md](SKILL.md) for AI agent configuration.

## Configuration

### Feed Refresh Interval

Feeds are refreshed every 15 minutes by default. To change this, edit `config/recurring.yml`:

```yaml
default: &default
  refresh_feeds:
    class: ScheduledRefreshJob
    queue: default
    schedule: every 30 minutes  # Change to your preferred interval
```

### Background Jobs

The application uses **Solid Queue** for background processing:
- Feed refresh jobs
- Article fetching
- OPML imports

Jobs are configured in `config/queue.yml` and `config/recurring.yml`.

## Architecture

### Models

- **User** - Authentication and user data
- **Feed** - RSS/Atom feed sources
- **Subscription** - User's feed subscriptions with categories
- **Article** - Individual feed entries
- **ArticleState** - Per-user article states (read/starred/archived)

### Services

- **FeedDiscoveryService** - Auto-discovers feeds from website URLs
- **FeedFetcherService** - Fetches and parses feed articles
- **OpmlService** - OPML import/export functionality

### Jobs

- **FeedRefreshJob** - Refreshes a single feed
- **ScheduledRefreshJob** - Queues all feeds for refresh (runs every 15 min)

## Deployment

### Using Docker

Review the Docker quick start in [`docs/docker.md`](docs/docker.md) for both single-container and docker-compose deployments.

### Using Kamal

Rails 8 includes Kamal deployment configuration:

```bash
bundle exec kamal setup
bundle exec kamal deploy
```

The configuration is prepped for deploying to a single DigitalOcean Droplet – follow [`docs/deployment/digitalocean-kamal.md`](docs/deployment/digitalocean-kamal.md) for a full walkthrough.

### Manual Deployment

1. Set environment variables:
   ```bash
   export RAILS_ENV=production
   export RAILS_MASTER_KEY=<your-key>
   export SECRET_KEY_BASE=<your-secret>
   ```

2. Precompile assets:
   ```bash
   bin/rails assets:precompile
   ```

3. Run migrations:
   ```bash
   bin/rails db:migrate
   ```

4. Start the web server:
   ```bash
   bin/rails server -e production
   ```

5. Start the background worker:
   ```bash
   bin/rails solid_queue:start
   ```

## Troubleshooting

### Feeds not updating
- Check Solid Queue is running: `bin/rails solid_queue:start`
- Check logs: `tail -f log/production.log`
- Manually trigger refresh: `FeedRefreshJob.perform_now(feed_id)`

### Feed discovery fails
- Ensure the website has an RSS/Atom feed
- Check the feed URL is publicly accessible
- Look for `<link>` tags with `type="application/rss+xml"` in the HTML

### Dark mode not persisting
- Ensure JavaScript is enabled
- Check browser localStorage is accessible
- Clear browser cache and reload

## Development

### Running Tests
```bash
bin/rails test
bin/rails test:system
```

### Code Quality
```bash
bin/rubocop
bin/brakeman
```

### Database Console
```bash
bin/rails dbconsole
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is available as open source under the terms of the [MIT License](LICENSE).

## REST API for Mobile Apps

Silo includes a comprehensive REST API for building mobile applications. See [API Documentation](docs/api/API_DOCUMENTATION.md) for complete API docs.

### Quick API Start

1. **Register/Login** to get your API token:
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123","password_confirmation":"password123"}'
```

2. **Use the token** in subsequent requests:
```bash
curl -X GET http://localhost:3000/api/v1/feeds \
  -H "Authorization: Bearer YOUR_API_TOKEN"
```

### API Features

- **Token-based authentication** (no session cookies)
- **Feed discovery** (paste any URL, we find the feed)
- **Full CRUD** for feeds and subscriptions
- **Article management** with read/starred/archived states
- **Full-text search** across all articles
- **Filtering & pagination** for article lists
- **Mobile-ready JSON responses**

See the complete [API Documentation](docs/api/API_DOCUMENTATION.md)

Example mobile app implementations available in:
- **iOS (Swift)** - See API docs
- **Android (Kotlin)** - See API docs
- **React Native** - See API docs

---

## Acknowledgments

- Built with [Rails 8](https://rubyonrails.org/)
- Styled with [Tailwind CSS](https://tailwindcss.com/)
- Feed parsing by [Feedjira](https://github.com/feedjira/feedjira)
- Background jobs by [Solid Queue](https://github.com/basecamp/solid_queue)

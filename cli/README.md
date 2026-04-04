# Silo CLI

A command-line interface for [Silo](https://github.com/silo/silo) - your personal RSS feed reader.

## Installation

### From Source

```bash
cd cli
bundle install
```

### Usage

The CLI provides subcommands for authentication, feed management, and article reading.

```bash
# Show help
bundle exec silo help

# Authentication
bundle exec silo auth login
bundle exec silo auth status

# Feed management
bundle exec silo feeds list
bundle exec silo feeds add https://example.com/feed.xml

# Articles
bundle exec silo articles list
bundle exec silo articles show 123
```

## Configuration

The CLI stores configuration in `~/.silo/config.yml`:

```yaml
api_url: http://localhost:3000/api/v1
token: your_api_token_here
email: user@example.com
```

You can also set environment variables:
- `SILO_API_URL` - API base URL
- `SILO_TOKEN` - API token (overrides config file)

## Commands

### Authentication

#### `silo auth login`

Authenticate with your Silo server and store the token.

```bash
silo auth login
# Enter email and password when prompted
```

Options:
- `--api-url URL` - API URL (default: http://localhost:3000/api/v1)

#### `silo auth status`

Check authentication status and token validity.

```bash
silo auth status
# Shows: logged in user, API URL, token validity
```

#### `silo auth logout`

Remove stored credentials.

```bash
silo auth logout
```

#### `silo auth cli_token`

Generate a non-expiring CLI token (useful for scripts and AI agents).

```bash
silo auth cli_token
# Returns a token that never expires
```

### Feeds

#### `silo feeds list`

List all subscribed feeds with unread counts.

```bash
silo feeds list
# Output:
# 3 feeds:
# 1. [Technology] TechCrunch (5 unread)
#    https://techcrunch.com/feed
# 2. [News] Hacker News (12 unread)
#    https://news.ycombinator.com/rss
```

Options:
- `--format json` - Output as JSON

#### `silo feeds add URL`

Subscribe to a new feed.

```bash
# Add by URL (auto-discovers feed)
silo feeds add https://example.com/blog

# Add with category
silo feeds add https://example.com/blog --category "Technology"

# Add with custom name
silo feeds add https://example.com/blog --name "My Custom Name"
```

#### `silo feeds remove FEED_ID`

Unsubscribe from a feed.

```bash
silo feeds remove 1
```

#### `silo feeds sync`

Trigger a background sync of all feeds.

```bash
silo feeds sync
# Queues background jobs to refresh all feeds
```

#### `silo feeds export_opml`

Export subscriptions to OPML format.

```bash
silo feeds export_opml > my_feeds.opml
# or
silo feeds export_opml --output my_feeds.opml
```

#### `silo feeds import_opml FILE`

Import subscriptions from OPML file.

```bash
silo feeds import_opml my_feeds.opml
silo feeds import_opml my_feeds.opml --category "Imported"
```

### Articles

#### `silo articles list`

List articles with various filters.

```bash
# List all unread articles (default)
silo articles list

# List unread only
silo articles list --filter=unread

# List starred articles
silo articles list --filter=starred

# List from specific feed
silo articles list --feed-id=1

# List 50 articles
silo articles list --limit=50

# Compact view (faster, less data)
silo articles list --compact

# Output as JSON
silo articles list --format=json
```

#### `silo articles show ARTICLE_ID`

Display full article content.

```bash
silo articles show 123
# Shows: title, feed, date, URL, and content
```

Options:
- `--no-content` - Show metadata only, skip content

#### `silo articles read ARTICLE_ID`

Mark an article as read.

```bash
silo articles read 123
```

#### `silo articles unread ARTICLE_ID`

Mark an article as unread.

```bash
silo articles unread 123
```

#### `silo articles star ARTICLE_ID`

Star an article.

```bash
silo articles star 123
```

#### `silo articles unstar ARTICLE_ID`

Remove star from an article.

```bash
silo articles unstar 123
```

#### `silo articles archive ARTICLE_ID`

Archive an article.

```bash
silo articles archive 123
```

#### `silo articles unarchive ARTICLE_ID`

Unarchive an article.

```bash
silo articles unarchive 123
```

#### `silo articles mark_read`

Bulk mark articles as read.

```bash
# Mark by IDs
silo articles mark_read --ids=1,2,3,4,5

# Mark by file (one ID per line)
silo articles mark_read --ids-file=article_ids.txt

# Mark all as read
silo articles mark_read --all

# Mark feed as read
silo articles mark_read --feed-id=1

# Mark category as read
silo articles mark_read --category="Technology"
```

#### `silo articles search QUERY`

Search articles by keyword.

```bash
silo articles search "machine learning"
silo articles search "ruby" --limit=20
```

### Sync

#### `silo sync`

Perform a delta sync with the server (for offline apps).

```bash
# Initial sync (gets everything)
silo sync

# Delta sync (gets only changes since last sync)
silo sync --since 2025-01-01T00:00:00Z

# Output to file
silo sync --output sync_data.json
```

### MCP Server

#### `silo mcp`

Start the MCP (Model Context Protocol) server for AI agent integration.

```bash
silo mcp
# Starts JSON-RPC server on stdin/stdout
```

This mode is used by AI agents like Claude to interact with your feeds. See [SKILL.md](../SKILL.md) for AI agent configuration.

## Examples

### Daily Workflow

```bash
# Check what's unread
silo feeds list
silo articles list --filter=unread --limit=10

# Read an article
silo articles show 123

# Mark as read when done
silo articles read 123

# Or mark all in a feed as read
silo articles mark_read --feed-id=1
```

### Backup and Restore

```bash
# Export all feeds
silo feeds export_opml > silo_backup.opml

# Import on another machine
silo feeds import_opml silo_backup.opml
```

### Automation Script

```bash
#!/bin/bash
# daily_digest.sh - Email yourself unread articles

export SILO_TOKEN="your_cli_token"

# Get unread count
COUNT=$(silo articles list --filter=unread --limit=50 --format=json | jq '.articles | length')

if [ "$COUNT" -gt 0 ]; then
  echo "You have $COUNT unread articles"
  silo articles list --filter=unread --limit=10
else
  echo "No new articles"
fi
```

## AI Agent Integration

The CLI includes an MCP server for AI agents. To use with Claude Desktop or other MCP clients:

1. Generate a CLI token:
   ```bash
   silo auth cli_token
   ```

2. Add to your MCP client configuration:
   ```json
   {
     "mcpServers": {
       "silo": {
         "command": "silo",
         "args": ["mcp"],
         "env": {
           "SILO_TOKEN": "your_cli_token",
           "SILO_API_URL": "http://localhost:3000/api/v1"
         }
       }
     }
   }
   ```

See [SKILL.md](../SKILL.md) for detailed AI agent configuration.

## Troubleshooting

### Connection Errors

If you get connection errors:

1. Check the API URL:
   ```bash
   silo auth status
   ```

2. Verify the server is running:
   ```bash
   curl http://localhost:3000/api/v1/health
   ```

3. Check your token is valid:
   ```bash
   silo auth status
   # If invalid, login again:
   silo auth login
   ```

### Rate Limiting

If you hit rate limits (300 req/min for authenticated users):

- Use `--limit` to reduce API calls
- Use `sync` instead of repeatedly listing
- Consider using the compact endpoint for lists

### SSL/TLS Errors

For self-signed certificates in development:

```bash
# Not recommended for production
export SSL_CERT_FILE=/path/to/cert.pem
silo feeds list
```

## Development

To contribute to the CLI:

```bash
cd cli
bundle install
bundle exec rspec  # Run tests
```

## License

MIT License - see main project LICENSE file.

## Support

- API Documentation: [docs/api/API_DOCUMENTATION.md](../docs/api/API_DOCUMENTATION.md)
- OpenAPI Spec: [openapi.yaml](../openapi.yaml)
- Main Project: https://github.com/silo/silo
- Issues: https://github.com/silo/silo/issues

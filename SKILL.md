# Silo - RSS Feed Reader SKILL

## Name
silo

## Description
Access and manage RSS feeds and articles through the Silo RSS reader. Read articles, manage subscriptions, search content, and track read/unread/starred states.

## Version
1.0.0

## Author
Silo Contributors

## Configuration

### Environment Variables
- `SILO_TOKEN` - Your Silo CLI token (non-expiring). Get one via the web interface at /settings or via API at POST /api/v1/auth/cli_token
- `SILO_API_URL` - API base URL (default: http://localhost:3000/api/v1)

### Setup
1. Generate a CLI token:
   ```bash
   curl -X POST https://your-silo-instance.com/api/v1/auth/cli_token \
     -H "Authorization: Bearer YOUR_API_TOKEN"
   ```

2. Set environment variable:
   ```bash
   export SILO_TOKEN=your_cli_token_here
   export SILO_API_URL=https://your-silo-instance.com/api/v1
   ```

## Tools

### silo_list_feeds
List all subscribed RSS feeds with unread counts.

**Parameters:** None

**Returns:**
- Feed names and categories
- Unread article counts per feed
- Feed URLs

---

### silo_get_unread_articles
Get unread articles, optionally filtered by feed.

**Parameters:**
- `feed_id` (integer, optional): Filter to specific feed
- `limit` (integer, optional): Max articles to return (default: 20, max: 100)

**Returns:**
- Article IDs, titles, feed names
- Publication dates
- Article URLs

---

### silo_get_starred_articles
Get starred/saved articles.

**Parameters:**
- `limit` (integer, optional): Max articles to return (default: 20)

**Returns:**
- Starred article details

---

### silo_search_articles
Search articles by keyword in title or content.

**Parameters:**
- `query` (string, required): Search query
- `limit` (integer, optional): Max results (default: 20)

**Returns:**
- Matching articles with snippets

---

### silo_mark_read
Mark one or more articles as read.

**Parameters:**
- `article_ids` (array of integers, required): Article IDs to mark read

**Returns:**
- Success confirmation
- Count of articles marked

---

### silo_subscribe_feed
Subscribe to a new RSS feed by URL.

**Parameters:**
- `url` (string, required): RSS feed URL or website URL to discover
- `category` (string, optional): Category for organization
- `name` (string, optional): Custom display name

**Returns:**
- Success confirmation
- New feed details

---

### silo_get_article_content
Get the full content of a specific article.

**Parameters:**
- `article_id` (integer, required): Article ID

**Returns:**
- Full article content (HTML stripped)
- Title, feed name, publication date
- Original URL

---

### silo_get_unread_count
Get the total count of unread articles.

**Parameters:** None

**Returns:**
- Total unread count

## Usage Examples

### Check what's unread
User: "What articles do I have unread?"

Agent calls `silo_get_unread_articles` with limit: 10

Response: "You have 42 unread articles. Here are the latest 10:
1. 'Rails 8 Released' from Ruby Weekly
2. 'AI Breakthroughs in 2025' from Hacker News
..."

### Read specific content
User: "Tell me about article 1234"

Agent calls `silo_get_article_content` with article_id: 1234

Response: Provides full article content summary

### Mark as read
User: "Mark those articles as read"

Agent calls `silo_mark_read` with the article_ids

Response: "Marked 3 articles as read. You now have 39 unread."

### Search
User: "Find articles about machine learning"

Agent calls `silo_search_articles` with query: "machine learning"

Response: "Found 12 articles about machine learning. The most recent is..."

### Subscribe
User: "Subscribe me to https://example.com/blog"

Agent calls `silo_subscribe_feed` with the URL

Response: "Successfully subscribed to Example Blog. Found 5 unread articles."

## API Reference

The underlying API follows REST conventions:
- Base URL: `/api/v1`
- Authentication: Bearer token in `Authorization` header
- Content-Type: `application/json`

### Key Endpoints
- `GET /articles` - List articles with pagination
- `GET /articles/search?q={query}` - Search articles
- `POST /articles/batch_update` - Bulk operations
- `GET /feeds` - List subscribed feeds
- `POST /feeds/discover` - Auto-discover feed from URL
- `GET /sync?since={timestamp}` - Delta sync for offline apps

See full API documentation at `docs/api/API_DOCUMENTATION.md`

## CLI Usage

Install the CLI:
```bash
gem install silo-cli
```

Common commands:
```bash
# Authenticate
silo auth login

# List feeds
silo feeds list

# Get unread articles
silo articles list --filter=unread

# Search
silo articles search "machine learning"

# Mark as read
silo articles read 1234

# MCP Server mode (for AI agents)
silo mcp
```

## Rate Limits
- 300 requests/minute per token (authenticated)
- 60 requests/minute per IP (unauthenticated)

## Error Handling
All tools return structured error responses:
- `isError: true` when an operation fails
- Error messages in `content` array
- HTTP status codes in responses

Common errors:
- 401: Invalid or expired token
- 403: Account pending approval
- 404: Resource not found
- 429: Rate limit exceeded
- 422: Invalid parameters

## Notes
- Articles can be in three states: read, starred, archived
- Archived articles are excluded from default views
- Full-text search uses SQLite FTS5 when available
- API supports both offset and cursor-based pagination

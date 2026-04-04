# Silo API Documentation

Version: 1.1  
Base URL: `https://your-domain.com/api/v1`

All dates/times returned by the API are ISO 8601 strings (UTC). Clients can convert them to the user's preferred timezone.

## What's New in v1.1

- **Delta Sync** (`/sync`) for efficient mobile offline support
- **Compact Articles** (`/articles/compact`) for fast list loading
- **CLI Tokens** (`/auth/cli_token`) for non-expiring AI agent access
- **Cursor Pagination** for better mobile list handling
- **Feed Icons** (`/feeds/:id/icon`) for favicon proxying

## Table of Contents

- [Authentication](#authentication)
- [Feeds](#feeds)
- [Articles](#articles)
- [Sync](#sync-for-mobile-apps)
- [CLI Tokens](#cli-tokens)
- [Rate Limits & CORS](#rate-limits--cors)
- [Examples](#examples)

## Authentication

Requests (except registration/login) require a Bearer token:

```
Authorization: Bearer YOUR_API_TOKEN
```

### Register a New User

**POST** `/api/v1/auth/register`

Registers a new user and returns an API token.

```json
{
  "email": "user@example.com",
  "password": "securepassword",
  "password_confirmation": "securepassword"
}
```

**201 Created**
```json
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "api_token": "a1b2c3d4e5f6...",
    "confirmed": true
  },
  "message": "Account created and confirmed."
}
```

### Login

**POST** `/api/v1/auth/login`

Authenticates with email/password and returns an API token + expiry.

```json
{
  "email": "user@example.com",
  "password": "securepassword"
}
```

**200 OK**
```json
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "api_token": "a1b2c3d4e5f6...",
    "api_token_expires_at": "2025-01-02T10:30:00Z"
  }
}
```

### Request Password Reset

**POST** `/api/v1/passwords`

Sends reset instructions to the provided email address. Always returns success to avoid leaking registered emails.

```json
{
  "email": "user@example.com"
}
```

**200 OK**
```json
{
  "message": "If your account exists, we've emailed password reset instructions."
}
```

### Reset Password

**PATCH** `/api/v1/passwords/{token}`

Updates the password using the token from the reset email. Tokens expire after 15 minutes.

```json
{
  "password": "newsecurepassword",
  "password_confirmation": "newsecurepassword"
}
```

**200 OK**
```json
{
  "message": "Password has been reset."
}
```

### Refresh Token

**POST** `/api/v1/auth/refresh`

Exchanges a valid token for a fresh one (resets expiration).

### Logout

**DELETE** `/api/v1/auth/logout`

Invalidates the current token. Returns **204 No Content**.

---

## Feeds

### List Subscriptions

**GET** `/api/v1/feeds`

Returns the authenticated user's subscriptions.

```json
[
  {
    "id": 12,
    "category": "Tech",
    "custom_name": "Daily Tech",
    "feed": {
      "id": 4,
      "title": "TechCrunch",
      "feed_url": "https://techcrunch.com/feed",
      "site_url": "https://techcrunch.com",
      "last_fetched_at": "2025-10-07T12:00:00Z"
    }
  }
]
```

### Browse Available Feeds

**GET** `/api/v1/feeds/browse`

Returns up to 100 recently added feeds in the system (useful for discovery UIs).

### Discover a Feed

**POST** `/api/v1/feeds/discover`

Auto-discovers an RSS/Atom feed from a website URL or validates a direct feed URL.

```json
{
  "url": "https://example.com"
}
```

**200 OK**
```json
{
  "feed": {
    "id": 7,
    "title": "Example Blog",
    "feed_url": "https://example.com/feed.xml",
    "site_url": "https://example.com"
  }
}
```

### Subscribe to a Feed

**POST** `/api/v1/feeds`

```json
{
  "feed_id": 7,
  "category": "Tech",
  "custom_name": "Example"
}
```

Enqueues a refresh of the feed on success. Returns **201 Created** with subscription details.

### Unsubscribe

**DELETE** `/api/v1/feeds/:id`

`id` is the feed ID. Returns **204 No Content** when the subscription exists; **404** otherwise.

### Feed Icon

**GET** `/api/v1/feeds/:id/icon`

Returns a redirect to the feed's favicon. If no favicon is found, redirects to a default icon. Useful for mobile apps to display feed icons without parsing HTML.

**302 Redirect** to icon URL

---

## Articles

### List Articles

**GET** `/api/v1/articles`

Query params:
- `feed_id` – filter by feed
- `category` – filter by category
- `filter` – `unread`, `starred`, `archived`; omit for the default (excludes archived)
- `limit` (default 50, max 100)
- `offset` – legacy offset pagination (deprecated, use cursor)
- `cursor` – cursor for pagination (preferred for mobile)

Response includes truncated content (`300` chars) to reduce payload size.

**Cursor Pagination Response:**
```json
{
  "articles": [...],
  "pagination": {
    "next_cursor": "eyJpZCI6MTIz...",
    "has_more": true
  }
}
```

### Compact Articles List

**GET** `/api/v1/articles/compact`

Returns a minimal article list optimized for fast loading on mobile devices.

Query params:
- `feed_id` – filter by feed
- `filter` – `unread`, `starred`
- `limit` (default 100)
- `cursor` – for pagination

**200 OK**
```json
{
  "articles": [
    {
      "id": 1,
      "title": "Article Title",
      "feed_name": "Feed Name",
      "feed_id": 5,
      "published_at": "2025-01-01T12:00:00Z",
      "read": false,
      "starred": true
    }
  ],
  "pagination": {
    "next_cursor": "eyJpZCI6MTAw...",
    "has_more": false
  }
}
```

### Retrieve an Article

**GET** `/api/v1/articles/:id`

Returns the full content plus state (read/starred/archived).

### Update Article State

- **PATCH** `/api/v1/articles/:id/mark_read` with `{ "read": true }`
- **PATCH** `/api/v1/articles/:id/mark_starred` with `{ "starred": true }`
- **PATCH** `/api/v1/articles/:id/mark_archived` with `{ "archived": true }`

Each endpoint returns the full state payload (`read`, `starred`, `archived`) after the update.

### Search

**GET** `/api/v1/articles/search?q=term`

Searches title and content. Returns truncated results.

### Unread Count

**GET** `/api/v1/articles/unread_count`

Returns `{ "unread_count": 42 }` for quick badge updates.

### Batch Update

**POST** `/api/v1/articles/batch_update`

Bulk update article states. Parameters:

```json
{
  "article_ids": [100, 101, 102],
  "bulk_action": "mark_read",
  "value": true
}
```

`bulk_action` supports `mark_read`, `mark_starred`, `mark_archived`. Returns counts of records affected.

### Mark All as Read

**POST** `/api/v1/articles/mark_all_read`

Optional filters:

```json
{
  "feed_id": 4,
  "category": "Tech"
}
```

Marks matching unread articles as read. Returns the number updated.

---

## Sync (for Mobile Apps)

The sync endpoints are designed for offline-first mobile applications. They provide delta updates since a given timestamp, allowing efficient synchronization.

### Delta Sync

**GET** `/api/v1/sync?since=2025-01-01T00:00:00Z`

Returns all changes since the provided timestamp. If no `since` param is provided, returns all data (useful for initial sync).

**200 OK**
```json
{
  "sync_meta": {
    "synced_at": "2025-01-15T10:30:00Z",
    "since": "2025-01-01T00:00:00Z",
    "has_more": false
  },
  "articles": {
    "added": [
      {
        "id": 100,
        "title": "New Article",
        "content": "Truncated content...",
        "url": "https://example.com/article",
        "published_at": "2025-01-10T12:00:00Z",
        "feed": {
          "id": 5,
          "title": "Feed Name"
        },
        "state": {
          "read": false,
          "starred": false,
          "archived": false
        }
      }
    ],
    "updated": []
  },
  "feeds": {
    "added": [],
    "updated": [],
    "deleted": []
  },
  "states": [
    {
      "article_id": 50,
      "read": true,
      "starred": false,
      "archived": false,
      "updated_at": "2025-01-15T09:00:00Z"
    }
  ]
}
```

**Notes:**
- `articles.added` includes both new articles and articles with updated content
- `articles.updated` is currently included for compatibility (may be removed)
- `feeds.deleted` contains feed IDs the user unsubscribed from since the last sync
- `states` contains all article state changes (read/starred/archived)
- If `has_more` is true, fetch again with the same `since` parameter to get more data (limited to 500 articles per request)

### Sync Status

**GET** `/api/v1/sync_status?since=2025-01-01T00:00:00Z`

Quick status check for mobile apps to determine if a full sync is needed. Useful for displaying unread badges and checking for updates without downloading all data.

Query params:
- `since` – ISO 8601 timestamp of last sync

**200 OK**
```json
{
  "unread_count": 42,
  "total_articles": 150,
  "starred_count": 12,
  "feeds_count": 8,
  "has_updates": true,
  "last_sync_at": "2025-01-15T10:30:00Z"
}
```

**Notes:**
- `has_updates` is true if there are new articles since the provided `since` timestamp
- If no `since` is provided, `has_updates` will always be true
- Use this endpoint for quick badge updates; use `/sync` for full data synchronization

---

## CLI Tokens

CLI tokens are non-expiring API tokens designed for command-line tools and AI agents. Unlike regular API tokens that expire after 90 days, CLI tokens remain valid until explicitly revoked.

### Generate CLI Token

**POST** `/api/v1/auth/cli_token`

Generates a new CLI token. If a token already exists, it will be replaced.

**200 OK**
```json
{
  "cli_token": "a1b2c3d4e5f6...",
  "generated_at": "2025-01-15T10:30:00Z",
  "note": "This token does not expire. Keep it secure."
}
```

### Revoke CLI Token

**DELETE** `/api/v1/auth/cli_token`

Revokes the current CLI token.

**200 OK**
```json
{
  "message": "CLI token revoked successfully"
}
```

**404 Not Found** – If no CLI token exists

### Check CLI Token Status

**GET** `/api/v1/auth/cli_token/status`

Checks if a CLI token exists.

**200 OK**
```json
{
  "exists": true,
  "generated_at": "2025-01-15T10:30:00Z"
}
```

or

```json
{
  "exists": false
}
```

### Using CLI Tokens

CLI tokens are used exactly like regular API tokens:

```
Authorization: Bearer YOUR_CLI_TOKEN
```

Store CLI tokens securely (e.g., in `~/.silo/config` or environment variables). They provide the same access as regular tokens but never expire, making them ideal for:
- Command-line tools
- Background scripts
- AI agent integration (MCP servers)
- Automation workflows

---

## Rate Limits & CORS

- Global: 60 requests/minute per IP
- Authenticated: 300 requests/minute per token
- Login throttling: 5 attempts per 20 seconds per email
- Registration throttling: 3/hour per IP

CORS is enabled via `config/initializers/cors.rb`. Configure allowed origins with the `CORS_ORIGINS` environment variable.

---

## Examples

### cURL Examples

```bash
# Login
curl -X POST https://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123"}'

# Generate CLI token
curl -X POST https://localhost:3000/api/v1/auth/cli_token \
  -H "Authorization: Bearer $TOKEN"

# Fetch subscriptions
curl -H "Authorization: Bearer $TOKEN" \
  https://localhost:3000/api/v1/feeds

# Compact articles (for mobile)
curl -H "Authorization: Bearer $TOKEN" \
  "https://localhost:3000/api/v1/articles/compact?limit=20&filter=unread"

# Cursor-based pagination
curl -H "Authorization: Bearer $TOKEN" \
  "https://localhost:3000/api/v1/articles?cursor=eyJpZCI6MTAwfQ&limit=50"

# Delta sync
curl -H "Authorization: Bearer $TOKEN" \
  "https://localhost:3000/api/v1/sync?since=2025-01-01T00:00:00Z"

# Batch mark read
curl -X POST https://localhost:3000/api/v1/articles/batch_update \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"article_ids":[1,2,3],"bulk_action":"mark_read","value":true}'

# Get feed icon
curl -L -H "Authorization: Bearer $TOKEN" \
  https://localhost:3000/api/v1/feeds/1/icon \
  -o feed_icon.ico
```

### TypeScript Snippet

```ts
const API = 'https://localhost:3000/api/v1';
let token = '';

export async function login(email: string, password: string) {
  const res = await fetch(`${API}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password })
  });
  const data = await res.json();
  token = data.user.api_token;
  return data;
}

export async function generateCliToken() {
  const res = await fetch(`${API}/auth/cli_token`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` }
  });
  return res.json();
}

export async function sync(since?: string) {
  const url = since 
    ? `${API}/sync?since=${encodeURIComponent(since)}`
    : `${API}/sync`;
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` }
  });
  return res.json();
}

export async function getUnreadCount() {
  const res = await fetch(`${API}/articles/unread_count`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  return res.json();
}

export async function markArticlesRead(ids: number[]) {
  return fetch(`${API}/articles/batch_update`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ article_ids: ids, bulk_action: 'mark_read', value: true })
  });
}
```

### Mobile Sync Workflow

```typescript
// Example: React Native or Flutter sync pattern

class SiloSyncManager {
  private lastSyncAt: string | null = null;
  private cursor: string | null = null;

  async performSync(): Promise<void> {
    // 1. Check if sync is needed
    const status = await this.getSyncStatus();
    if (!status.has_updates && this.lastSyncAt) {
      console.log('No updates needed');
      return;
    }

    // 2. Fetch delta changes
    const syncData = await this.fetchDeltaSync();
    
    // 3. Apply changes to local database
    await this.applyChanges(syncData);
    
    // 4. Update sync timestamp
    this.lastSyncAt = syncData.sync_meta.synced_at;
    
    // 5. Check if more data available
    if (syncData.sync_meta.has_more) {
      await this.performSync(); // Recursive call
    }
  }

  private async getSyncStatus() {
    const response = await fetch(
      `${API}/sync_status?since=${this.lastSyncAt || ''}`,
      { headers: { Authorization: `Bearer ${token}` } }
    );
    return response.json();
  }

  private async fetchDeltaSync() {
    const response = await fetch(
      `${API}/sync?since=${this.lastSyncAt || ''}`,
      { headers: { Authorization: `Bearer ${token}` } }
    );
    return response.json();
  }

  private async applyChanges(data: any): Promise<void> {
    // Insert new articles
    for (const article of data.articles.added) {
      await db.articles.insert(article);
    }
    
    // Update states
    for (const state of data.states) {
      await db.articleStates.update(state.article_id, state);
    }
    
    // Handle deleted feeds
    for (const feedId of data.feeds.deleted) {
      await db.feeds.delete(feedId);
    }
  }
}
```

---

## Additional Resources

- **OpenAPI Specification**: See `openapi.yaml` in the repository root
- **CLI Tool**: See `cli/README.md` for command-line usage
- **AI Agent Integration**: See `SKILL.md` for MCP server configuration
- **Rails Routes**: Run `bin/rails routes` to see all available endpoints

For bug reports or feature requests, please open an issue on the project repository.

# Silo API Documentation

Version: 1.0  
Base URL: `https://your-domain.com/api/v1`

All dates/times returned by the API are ISO 8601 strings (UTC). Clients can convert them to the user’s preferred timezone.

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
    "api_token": "a1b2c3d4e5f6..."
  }
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

Returns the authenticated user’s subscriptions.

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

---

## Articles

### List Articles

**GET** `/api/v1/articles`

Query params:
- `feed_id` – filter by feed
- `category` – filter by category
- `filter` – `unread`, `starred`, `archived`; omit for the default (excludes archived)
- `limit` (default 50)
- `offset` (default 0)

Response includes truncated content (`300` chars) to reduce payload size.

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

## Daily Briefs

Endpoints for the generated summaries Silo emails/displays.

### List Briefs

**GET** `/api/v1/daily_briefs`

Query params: `limit` (default 50) and `offset`. Response includes metadata (`total`, `unread_count`).

### Latest Brief

**GET** `/api/v1/daily_briefs/latest`

Returns the most recent brief (or `brief: null`). Viewing marks it as read.

### Retrieve a Brief

**GET** `/api/v1/daily_briefs/:id`

Returns the full summary (also marks it as read).

### Update Read State

- **PATCH** `/api/v1/daily_briefs/:id/mark_read`
- **PATCH** `/api/v1/daily_briefs/:id/mark_unread`

Each response returns `{ "read": true/false }`.

---

## Rate Limits & CORS

- Global: 60 requests/minute per IP
- Authenticated: 300 requests/minute per token
- Login throttling: 5 attempts per 20 seconds per email
- Registration throttling: 3/hour per IP

CORS is enabled via `config/initializers/cors.rb`. Configure allowed origins with the `CORS_ORIGINS` environment variable.

---

## Examples

### cURL

```bash
# Login
curl -X POST https://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password123"}'

# Fetch subscriptions
curl -H "Authorization: Bearer $TOKEN" \
  https://localhost:3000/api/v1/feeds

# Batch mark read
curl -X POST https://localhost:3000/api/v1/articles/batch_update \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"article_ids":[1,2,3],"bulk_action":"mark_read","value":true}'
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

For additional endpoints (password resets, daily-brief schedules, job dashboards) consult the Rails routes or reach out to the Silo team.

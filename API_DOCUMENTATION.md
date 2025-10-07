# Feed Reader API Documentation

Version: 1.0
Base URL: `http://your-domain.com/api/v1`

## Authentication

All API endpoints (except `/auth/login` and `/auth/register`) require authentication using a Bearer token in the Authorization header:

```
Authorization: Bearer YOUR_API_TOKEN
```

### Register a New User

**POST** `/api/v1/auth/register`

Register a new user account and receive an API token.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securepassword",
  "password_confirmation": "securepassword"
}
```

**Response (201 Created):**
```json
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "api_token": "a1b2c3d4e5f6..."
  }
}
```

**Error Response (422 Unprocessable Entity):**
```json
{
  "error": ["Email has already been taken", "Password is too short"]
}
```

### Login

**POST** `/api/v1/auth/login`

Authenticate with email and password to receive an API token.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securepassword"
}
```

**Response (200 OK):**
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

**Error Response (401 Unauthorized):**
```json
{
  "error": "Invalid email or password"
}
```

### Refresh Token

**POST** `/api/v1/auth/refresh`

Refresh your API token to get a new one with extended expiration.

**Headers:**
```
Authorization: Bearer YOUR_API_TOKEN
```

**Response (200 OK):**
```json
{
  "user": {
    "id": 1,
    "email": "user@example.com",
    "api_token": "new_token_xyz...",
    "api_token_expires_at": "2025-01-02T10:30:00Z"
  }
}
```

### Logout

**DELETE** `/api/v1/auth/logout`

Invalidate your current API token.

**Headers:**
```
Authorization: Bearer YOUR_API_TOKEN
```

**Response (204 No Content)**

---

## Feeds

### Get All Subscribed Feeds

**GET** `/api/v1/feeds`

Retrieve all feeds the authenticated user is subscribed to.

**Headers:**
```
Authorization: Bearer YOUR_API_TOKEN
```

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "category": "Tech",
    "custom_name": null,
    "feed": {
      "id": 1,
      "title": "TechCrunch",
      "feed_url": "https://techcrunch.com/feed",
      "site_url": "https://techcrunch.com",
      "last_fetched_at": "2025-10-03T10:00:00Z"
    }
  },
  {
    "id": 2,
    "category": "News",
    "custom_name": "My Custom Name",
    "feed": {
      "id": 2,
      "title": "BBC News",
      "feed_url": "https://feeds.bbci.co.uk/news/rss.xml",
      "site_url": "https://www.bbc.com/news",
      "last_fetched_at": "2025-10-03T09:55:00Z"
    }
  }
]
```

### Discover a Feed

**POST** `/api/v1/feeds/discover`

Auto-discover an RSS/Atom feed from a website URL or validate a direct feed URL.

**Headers:**
```
Authorization: Bearer YOUR_API_TOKEN
```

**Request Body:**
```json
{
  "url": "https://example.com"
}
```

**Response (200 OK):**
```json
{
  "feed": {
    "id": 3,
    "title": "Example Blog",
    "feed_url": "https://example.com/feed.xml",
    "site_url": "https://example.com"
  }
}
```

**Error Response (404 Not Found):**
```json
{
  "error": "Feed not found"
}
```

### Subscribe to a Feed

**POST** `/api/v1/feeds`

Subscribe the authenticated user to a feed.

**Headers:**
```
Authorization: Bearer YOUR_API_TOKEN
```

**Request Body:**
```json
{
  "feed_id": 3,
  "category": "Tech",
  "custom_name": "My Favorite Blog"
}
```

**Response (201 Created):**
```json
{
  "subscription": {
    "id": 10,
    "category": "Tech",
    "custom_name": "My Favorite Blog",
    "feed": {
      "id": 3,
      "title": "Example Blog",
      "feed_url": "https://example.com/feed.xml",
      "site_url": "https://example.com"
    }
  }
}
```

**Error Response (422 Unprocessable Entity):**
```json
{
  "error": ["User has already subscribed to this feed"]
}
```

### Unsubscribe from a Feed

**DELETE** `/api/v1/feeds/:id`

Unsubscribe from a feed.

**Headers:**
```
Authorization: Bearer YOUR_API_TOKEN
```

**Response (204 No Content)**

**Error Response (404 Not Found):**
```json
{
  "error": "Subscription not found"
}
```

---

## Articles

### Get All Articles

**GET** `/api/v1/articles`

Retrieve articles from all subscribed feeds with optional filters.

**Headers:**
```
Authorization: Bearer YOUR_API_TOKEN
```

**Query Parameters:**
- `feed_id` (optional): Filter by specific feed ID
- `category` (optional): Filter by category
- `filter` (optional): `unread`, `starred`, `archived`, or omit for default (excludes archived)
- `limit` (optional): Number of articles per page (default: 50)
- `offset` (optional): Pagination offset (default: 0)

**Example Request:**
```
GET /api/v1/articles?filter=unread&limit=20&offset=0
```

**Response (200 OK):**
```json
{
  "articles": [
    {
      "id": 100,
      "title": "Breaking: New Tech Announcement",
      "content": "<p>Full article content here...</p>",
      "url": "https://example.com/article-1",
      "published_at": "2025-10-03T08:30:00Z",
      "feed": {
        "id": 1,
        "title": "TechCrunch"
      },
      "state": {
        "read": false,
        "starred": false,
        "archived": false
      }
    }
  ],
  "meta": {
    "total": 150,
    "limit": 20,
    "offset": 0
  }
}
```

### Get a Single Article

**GET** `/api/v1/articles/:id`

Retrieve a specific article with full content.

**Headers:**
```
Authorization: Bearer YOUR_API_TOKEN
```

**Response (200 OK):**
```json
{
  "article": {
    "id": 100,
    "title": "Breaking: New Tech Announcement",
    "content": "<p>Full article content here...</p>",
    "url": "https://example.com/article-1",
    "published_at": "2025-10-03T08:30:00Z",
    "feed": {
      "id": 1,
      "title": "TechCrunch",
      "site_url": "https://techcrunch.com"
    },
    "state": {
      "read": true,
      "starred": false,
      "archived": false
    }
  }
}
```

**Error Response (404 Not Found):**
```json
{
  "error": "Couldn't find Article with 'id'=100"
}
```

### Mark Article as Read/Unread

**PATCH** `/api/v1/articles/:id/mark_read`

Update the read status of an article.

**Headers:**
```
Authorization: Bearer YOUR_API_TOKEN
```

**Request Body:**
```json
{
  "read": true
}
```

**Response (200 OK):**
```json
{
  "state": {
    "read": true
  }
}
```

### Star/Unstar an Article

**PATCH** `/api/v1/articles/:id/mark_starred`

Update the starred status of an article.

**Headers:**
```
Authorization: Bearer YOUR_API_TOKEN
```

**Request Body:**
```json
{
  "starred": true
}
```

**Response (200 OK):**
```json
{
  "state": {
    "starred": true
  }
}
```

### Archive/Unarchive an Article

**PATCH** `/api/v1/articles/:id/mark_archived`

Update the archived status of an article.

**Headers:**
```
Authorization: Bearer YOUR_API_TOKEN
```

**Request Body:**
```json
{
  "archived": true
}
```

**Response (200 OK):**
```json
{
  "state": {
    "archived": true
  }
}
```

### Search Articles

**GET** `/api/v1/articles/search`

Search articles by title or content.

**Headers:**
```
Authorization: Bearer YOUR_API_TOKEN
```

**Query Parameters:**
- `q` (required): Search query

**Example Request:**
```
GET /api/v1/articles/search?q=artificial+intelligence
```

**Response (200 OK):**
```json
{
  "articles": [
    {
      "id": 105,
      "title": "AI Breakthrough in Healthcare",
      "content": "Artificial intelligence has made significant progress...",
      "url": "https://example.com/ai-healthcare",
      "published_at": "2025-10-02T14:20:00Z",
      "feed": {
        "id": 2,
        "title": "Science Daily"
      },
      "state": {
        "read": false,
        "starred": true,
        "archived": false
      }
    }
  ]
}
```

---

## Mobile-Optimized Endpoints

### Get Unread Count

**GET** `/api/v1/articles/unread_count`

Get the total count of unread articles for the authenticated user.

**Headers:**
```
Authorization: Bearer YOUR_API_TOKEN
```

**Response (200 OK):**
```json
{
  "unread_count": 42
}
```

### Batch Update Articles

**POST** `/api/v1/articles/batch_update`

Update multiple articles at once (useful for syncing).

**Headers:**
```
Authorization: Bearer YOUR_API_TOKEN
```

**Request Body:**
```json
{
  "article_ids": [100, 101, 102],
  "action": "mark_read",
  "value": true
}
```

**Actions:**
- `mark_read` - Mark articles as read/unread
- `mark_starred` - Star/unstar articles
- `mark_archived` - Archive/unarchive articles

**Response (200 OK):**
```json
{
  "success": true,
  "updated_count": 3
}
```

### Mark All as Read

**POST** `/api/v1/articles/mark_all_read`

Mark all articles as read, optionally filtered by feed or category.

**Headers:**
```
Authorization: Bearer YOUR_API_TOKEN
```

**Request Body (optional filters):**
```json
{
  "feed_id": 1,
  "category": "Tech"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "marked_count": 25
}
```

---

## Performance & Caching

### Response Compression
All API responses are automatically gzip compressed to reduce bandwidth usage on mobile devices.

### ETag Support
The API supports HTTP ETags for efficient caching:
- Include `If-None-Match` header with the ETag value
- Server returns `304 Not Modified` if content hasn't changed
- Reduces bandwidth and improves response times

**Example:**
```bash
# First request
curl -H "Authorization: Bearer TOKEN" http://api/v1/articles
# Response includes: ETag: "abc123"

# Subsequent request
curl -H "Authorization: Bearer TOKEN" \
     -H "If-None-Match: abc123" \
     http://api/v1/articles
# Response: 304 Not Modified (if unchanged)
```

### Content Optimization
- Article list endpoints return truncated content (300 chars) to minimize payload size
- Use the detail endpoint (`GET /articles/:id`) to fetch full article content

---

## CORS Configuration

Cross-Origin Resource Sharing (CORS) is enabled for all API endpoints:
- Allowed methods: GET, POST, PUT, PATCH, DELETE, OPTIONS, HEAD
- Preflight requests are cached for 24 hours
- Configure allowed origins via `CORS_ORIGINS` environment variable in production

---

## Error Responses

### 401 Unauthorized
```json
{
  "error": "Unauthorized"
}
```

Returned when:
- No Authorization header is provided
- Invalid or expired API token
- Token doesn't match any user

### 404 Not Found
```json
{
  "error": "Couldn't find [Resource] with 'id'=[id]"
}
```

Returned when the requested resource doesn't exist or doesn't belong to the authenticated user.

### 422 Unprocessable Entity
```json
{
  "error": "Error message",
  "details": {
    "field": ["error details"]
  }
}
```

Returned when request validation fails.

---

## Rate Limiting

The API enforces rate limits to ensure fair usage and system stability:

### Rate Limit Tiers

1. **General API Requests** (per IP): 60 requests/minute
2. **Authenticated Requests** (per token): 300 requests/minute
3. **Login Attempts** (per email): 5 attempts/20 seconds
4. **Registration** (per IP): 3 registrations/hour

### Rate Limit Headers

When you make a request, the response includes rate limit information:
```
X-RateLimit-Limit: 300
X-RateLimit-Remaining: 299
```

### Rate Limit Exceeded Response (429)

```json
{
  "error": "Rate limit exceeded. Please try again later.",
  "retry_after": 60
}
```

The `Retry-After` header indicates seconds to wait before retrying.

---

## Example Usage

### cURL Examples

**Register:**
```bash
curl -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123",
    "password_confirmation": "password123"
  }'
```

**Login:**
```bash
curl -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123"
  }'
```

**Get Feeds:**
```bash
curl -X GET http://localhost:3000/api/v1/feeds \
  -H "Authorization: Bearer YOUR_API_TOKEN"
```

**Discover Feed:**
```bash
curl -X POST http://localhost:3000/api/v1/feeds/discover \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://techcrunch.com"
  }'
```

**Subscribe to Feed:**
```bash
curl -X POST http://localhost:3000/api/v1/feeds \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "feed_id": 1,
    "category": "Tech",
    "custom_name": "TC"
  }'
```

**Get Articles:**
```bash
curl -X GET "http://localhost:3000/api/v1/articles?filter=unread&limit=10" \
  -H "Authorization: Bearer YOUR_API_TOKEN"
```

**Mark as Read:**
```bash
curl -X PATCH http://localhost:3000/api/v1/articles/100/mark_read \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "read": true
  }'
```

**Search Articles:**
```bash
curl -X GET "http://localhost:3000/api/v1/articles/search?q=technology" \
  -H "Authorization: Bearer YOUR_API_TOKEN"
```

### JavaScript/TypeScript Example

```typescript
const API_BASE_URL = 'http://localhost:3000/api/v1';
let API_TOKEN = '';

// Login
async function login(email: string, password: string) {
  const response = await fetch(`${API_BASE_URL}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password })
  });

  const data = await response.json();
  API_TOKEN = data.user.api_token;
  return data;
}

// Get articles
async function getArticles(filter = 'unread', limit = 20) {
  const response = await fetch(
    `${API_BASE_URL}/articles?filter=${filter}&limit=${limit}`,
    {
      headers: { 'Authorization': `Bearer ${API_TOKEN}` }
    }
  );

  return await response.json();
}

// Mark article as read
async function markAsRead(articleId: number) {
  const response = await fetch(
    `${API_BASE_URL}/articles/${articleId}/mark_read`,
    {
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${API_TOKEN}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ read: true })
    }
  );

  return await response.json();
}
```

### Swift (iOS) Example

```swift
class FeedReaderAPI {
    let baseURL = "http://localhost:3000/api/v1"
    var apiToken: String?

    func login(email: String, password: String) async throws -> User {
        let url = URL(string: "\(baseURL)/auth/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(LoginResponse.self, from: data)

        self.apiToken = response.user.apiToken
        return response.user
    }

    func getArticles(filter: String = "unread") async throws -> [Article] {
        guard let token = apiToken else { throw APIError.unauthorized }

        let url = URL(string: "\(baseURL)/articles?filter=\(filter)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ArticlesResponse.self, from: data)

        return response.articles
    }
}
```

### Kotlin (Android) Example

```kotlin
class FeedReaderAPI(private val baseUrl: String = "http://localhost:3000/api/v1") {
    private var apiToken: String? = null
    private val client = OkHttpClient()
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun login(email: String, password: String): User {
        val body = JSONObject()
            .put("email", email)
            .put("password", password)

        val request = Request.Builder()
            .url("$baseUrl/auth/login")
            .post(body.toString().toRequestBody("application/json".toMediaType()))
            .build()

        val response = client.newCall(request).execute()
        val loginResponse = json.decodeFromString<LoginResponse>(response.body!!.string())

        apiToken = loginResponse.user.apiToken
        return loginResponse.user
    }

    suspend fun getArticles(filter: String = "unread"): List<Article> {
        val request = Request.Builder()
            .url("$baseUrl/articles?filter=$filter")
            .addHeader("Authorization", "Bearer $apiToken")
            .get()
            .build()

        val response = client.newCall(request).execute()
        return json.decodeFromString<ArticlesResponse>(response.body!!.string()).articles
    }
}
```

---

## Changelog

### Version 1.1 (2025-10-04) - Mobile-Ready Release
- **Mobile Optimizations:**
  - Added gzip response compression
  - Implemented ETag caching support
  - Truncated article content in list views (300 chars)
  - Added CORS support for cross-origin requests
- **Token Management:**
  - Added token expiration (90 days)
  - Added token refresh endpoint
  - Added logout endpoint
  - Token expiration info in auth responses
- **New Endpoints:**
  - GET `/api/v1/articles/unread_count` - Get unread article count
  - POST `/api/v1/articles/batch_update` - Batch update article states
  - POST `/api/v1/articles/mark_all_read` - Mark all articles as read
- **Security & Performance:**
  - Added rate limiting (60rpm general, 300rpm authenticated)
  - Login throttling (5 attempts/20s)
  - Registration throttling (3/hour)

### Version 1.0 (2025-10-03)
- Initial API release
- Authentication endpoints
- Feed management
- Article retrieval and state management
- Search functionality

---

## Support

For issues or questions about the API, please open an issue on GitHub or contact support.

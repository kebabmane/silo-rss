# Repository Guidelines

Silo is a Rails 8 RSS feed reader using Hotwire (Turbo + Stimulus), SQLite, Tailwind CSS, and Solid Queue. This guide helps agents work effectively in this codebase.

## Build, Test, and Development Commands

```bash
# Setup
bundle install                              # Install Ruby gems
bin/rails db:migrate                        # Run main DB migrations
bin/rails db:migrate SCHEMA=db/queue_schema.rb  # Solid Queue migrations
bin/rails db:seed                           # Seed database (if needed)

# Development
bin/dev                                     # Start dev server (web + CSS + jobs)
bin/rails server                            # Rails only
bin/rails tailwindcss:watch                 # Tailwind CSS watcher
bin/rails solid_queue:start                 # Background jobs only

# Testing - All tests
bin/rails test                              # Unit/integration tests
bin/rails test:system                       # Browser/system tests (needs Chrome)

# Testing - Single test files
bin/rails test test/services/feed_discovery_service_test.rb
bin/rails test test/controllers/feeds_controller_test.rb
bin/rails test test/models/user_test.rb
bin/rails test test/system/feed_management_test.rb

# Testing - Single test by name
bin/rails test -n test_discover_returns_feed_url_when_URL_is_a_direct_RSS_feed
bin/rails test test/services/feed_discovery_service_test.rb -n /discover/

# Testing with coverage (SimpleCov enabled by default in test_helper.rb)
bin/rails test
open coverage/index.html                    # View coverage report

# Linting and Security
bin/rubocop                                 # Run RuboCop linting
bin/rubocop -A                              # Auto-fix RuboCop issues
bin/brakeman                                # Security analysis

# Docker
bin/docker-dev                              # Docker dev environment

# Production build
bin/rails assets:precompile                 # Precompile assets
RAILS_ENV=production bin/rails server       # Production mode
```

## Project Structure

```
app/
  controllers/           # Rails controllers (thin)
    api/v1/             # API controllers
    admin/              # Admin controllers
  models/               # ActiveRecord models
  services/             # Business logic (FeedDiscoveryService, OpmlService, etc.)
  jobs/                 # Solid Queue background jobs
  views/                # ERB templates with Tailwind
  assets/               # Tailwind CSS, images, fonts
  javascript/           # Stimulus controllers (importmap, no webpack)

config/
  recurring.yml         # Solid Queue scheduled jobs
  queue.yml           # Solid Queue configuration

test/
  controllers/          # Controller tests
  integration/          # Integration/flow tests
  models/               # Model tests
  services/             # Service tests
  system/               # Browser/system tests
  fixtures/             # Test data (YAML)
```

## Code Style and Conventions

### Ruby Style (RuboCop enforced)
- Uses `rubocop-rails-omakase` as base style
- 2-space indentation (no tabs)
- Max method length: 20 lines
- Max class length: 150 lines (excludes tests)
- Max block length: 25 lines (excludes config, tests)
- snake_case for methods/variables
- CamelCase for classes/modules
- Single quotes for non-interpolated strings

### Naming Conventions
- Controllers: `FeedsController`, `Api::V1::ArticlesController`
- Services: `FeedDiscoveryService`, `OpmlService`
- Jobs: `FeedRefreshJob`, `ScheduledRefreshJob`
- Models: `User`, `ArticleState`, `DailyBriefSchedule`
- Custom errors: `FeedCreatorService::Error`, `User::UnconfirmedUserError`

### JavaScript/Stimulus
- Controllers: `app/javascript/controllers/*_controller.js`
- Use kebab-case for data attributes: `data-controller="feed-manager"`
- Import maps (no webpack/JS bundler)
- Stimulus targets/actions use kebab-case in HTML

### CSS/Tailwind
- Tailwind-first styling
- Avoid inline styles except small overrides
- Custom CSS in `app/assets/stylesheets/`

## Service Object Pattern

Services encapsulate business logic. Keep controllers thin.

```ruby
class FeedDiscoveryService
  def initialize(url)
    @url = normalize_url(url)
  end

  def discover
    return if @url.blank?
    # implementation
  end

  private

  def normalize_url(url)
    # private methods for internal logic
  end
end
```

### Service Conventions
- Initialize with parameters in `initialize`
- Single public method (often named `call`, `discover`, `perform`, etc.)
- Custom error classes as `ServiceName::Error`
- Return structured results (hash or object), not raw data

## Error Handling

### Controllers
- Rescue specific errors with custom error messages
- Log errors with context: `Rails.logger.error("Context: #{e.message}")`
- Use service error classes for domain errors

```ruby
rescue FeedCreatorService::Error => e
  Rails.logger.error("Feed creation error: #{e.message}")
  render_error_response
rescue SocketError, Timeout::Error, Errno::ECONNREFUSED => e
  Rails.logger.warn("Network error: #{e.message}")
  render_error_response
```

### Services
- Use early returns for guard clauses
- Log errors at service level before returning nil/failure
- Validate inputs with `UrlSafety.safe_uri_for()` for URLs

## Testing Guidelines

### Test Structure (Minitest)
```ruby
require "test_helper"

class FeedDiscoveryServiceTest < ActiveSupport::TestCase
  test "discover returns feed_url for direct RSS feed" do
    # Arrange
    feed_url = "https://example.com/feed.xml"
    stub_request(:get, feed_url).to_return(status: 200, body: rss_xml)

    # Act
    service = FeedDiscoveryService.new(feed_url)
    result = service.discover

    # Assert
    assert_equal feed_url, result[:feed_url]
  end
end
```

### Testing Patterns
- Use WebMock for HTTP stubbing: `stub_request(:get, url).to_return(...)`
- Use Mocha for mocking: `Feedjira.stubs(:parse).raises(...)`
- All fixture users have password: "password"
- SimpleCov runs automatically; check `coverage/index.html`

### Authentication Helpers
```ruby
# Controller tests
def login_as(user)
  session = user.sessions.create!
  cookies.signed.permanent[:session_id] = { value: session.id, httponly: true }
end

# Integration tests
def login_as(user)
  post session_path, params: { email_address: user.email_address, password: "password" }
  follow_redirect! if response.redirect?
end

# API tests
def api_headers(user)
  { "Authorization" => "Bearer #{user.api_token}" }
end
```

## API Development

- API controllers in `app/controllers/api/v1/`
- Token-based auth via `Authorization: Bearer <token>` header
- Base controller provides `current_user` from API token
- JSON responses using `render json: {}`

## Background Jobs (Solid Queue)

```ruby
class FeedRefreshJob < ApplicationJob
  queue_as :default

  def perform(feed_id)
    feed = Feed.find_by(id: feed_id)
    return unless feed
    # job logic
  end
end
```

- Use `perform_later` to queue jobs: `FeedRefreshJob.perform_later(feed.id)`
- Scheduled jobs configured in `config/recurring.yml`
- Monitor via Mission Control at `/admin/jobs`

## Database and Models

- SQLite in development and production
- Uses `encrypts` for sensitive fields (api_token)
- `has_secure_password` for password hashing
- Normalization: `normalizes :email_address, with: ->(e) { e.strip.downcase }`
- Validations with specific error messages

## Security Guidelines

- Never commit secrets (`.env`, `RAILS_MASTER_KEY`)
- Use `UrlSafety.safe_uri_for()` to prevent SSRF attacks
- Validate all user input
- Rate limiting via Rack::Attack (configured in middleware)
- CSRF protection enabled for web routes (API uses token auth)

## Commit Message Style

Short, imperative subjects:
- "Fix infinite scroll loading too many articles at once"
- "Add admin user auto-creation for HA addon"
- "Implement smart feed refreshing and fix broken schedule"
- "UI Fixes: Add aria-hidden to emoji and complete button styling"

## PR Checklist

- [ ] Run `bin/rails test` and `bin/rails test:system`
- [ ] Run `bin/rubocop` and `bin/brakeman`
- [ ] Update fixtures if schema changed
- [ ] Add tests for new behaviors
- [ ] Flag migrations/queue config changes in PR description

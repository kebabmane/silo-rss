# Configure CORS for API access from mobile apps and web clients
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Allow requests from any origin during development
    # In production, CORS_ORIGINS must be set (no wildcard fallback for security)
    origins Rails.env.production? ? (ENV["CORS_ORIGINS"]&.split(",") || []) : "*"

    resource "/api/*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: false,
      max_age: 86400 # Cache preflight requests for 24 hours
  end
end

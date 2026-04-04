# Configure CORS for API access from mobile apps and web clients
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # Allow requests from any origin during development
    # In production, CORS_ORIGINS must be set (no wildcard fallback for security)
    origins(
      if Rails.env.production?
        cors_origins = ENV["CORS_ORIGINS"]&.split(",")&.map(&:strip)
        if cors_origins.blank?
          Rails.logger.warn "[CORS] WARNING: CORS_ORIGINS env var not set — all cross-origin requests will be blocked. Set CORS_ORIGINS=https://yourdomain.com to allow API access."
          []
        else
          cors_origins
        end
      else
        "*"
      end
    )

    resource "/api/*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ],
      credentials: false,
      max_age: 86400 # Cache preflight requests for 24 hours
  end
end

# Configure Rack::Attack for API rate limiting
# Skip in test environment to avoid issues with request mocking
return if Rails.env.test?

class Rack::Attack
  # Throttle all requests by IP (60rpm)
  throttle("req/ip", limit: 60, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  # Throttle login attempts by email (5 attempts per 20 seconds)
  throttle("logins/email", limit: 5, period: 20.seconds) do |req|
    if req.path == "/api/v1/auth/login" && req.post?
      # Return the email if present
      req.params["email"].to_s.downcase.presence
    end
  end

  # Throttle registration attempts by IP (3 per hour)
  throttle("registrations/ip", limit: 3, period: 1.hour) do |req|
    if req.path == "/api/v1/auth/register" && req.post?
      req.ip
    end
  end

  # Throttle API requests by token (300rpm per user)
  throttle("api/token", limit: 300, period: 1.minute) do |req|
    if req.path.start_with?("/api/")
      # Extract token from Authorization header
      token = req.env["HTTP_AUTHORIZATION"]&.gsub("Bearer ", "")
      token if token.present?
    end
  end

  # Custom response for throttled requests
  self.throttled_responder = lambda do |env|
    match_data = env["rack.attack.match_data"] || {}
    retry_after = match_data[:period] || 60
    [
      429,
      {
        "Content-Type" => "application/json",
        "Retry-After" => retry_after.to_s
      },
      [{
        error: "Rate limit exceeded. Please try again later.",
        retry_after: retry_after
      }.to_json]
    ]
  end
end

# Enable Rack::Attack
Rails.application.config.middleware.use Rack::Attack

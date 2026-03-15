require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Only require master key at runtime, not during asset precompilation builds
  # SECRET_KEY_BASE_DUMMY=1 is set during Docker builds to bypass this requirement
  config.require_master_key = !ENV["SECRET_KEY_BASE_DUMMY"]

  # Support relative URL root for Home Assistant Ingress and other reverse proxy setups
  config.relative_url_root = ENV["RAILS_RELATIVE_URL_ROOT"] if ENV["RAILS_RELATIVE_URL_ROOT"].present?

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Allow HTTP for local Docker development (set DISABLE_SSL=true in .env)
  unless ENV["DISABLE_SSL"]
    # Assume all access to the app is happening through a SSL-terminating reverse proxy.
    config.assume_ssl = true

    # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
    config.force_ssl = true
  end

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # ActionCable allowed origins for WebSocket connections
  if ENV["ACTION_CABLE_ALLOWED_REQUEST_ORIGINS"] == "*"
    # Allow all origins (for Home Assistant Ingress where HA manages auth)
    config.action_cable.disable_request_forgery_protection = true
  else
    config.action_cable.allowed_request_origins = [
      "https://#{ENV.fetch('APPLICATION_HOST', 'localhost')}",
      "http://localhost:3000",  # Local Docker development
      "http://127.0.0.1:3000"
    ]
  end

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Configure outbound email via Mailgun.
  application_host = ENV.fetch("APPLICATION_HOST", "silo.hannah-co.com")
  mailer_from_address = ENV["MAILER_FROM_ADDRESS"].presence || "info@#{application_host}"
  mailgun_domain = ENV["MAILGUN_DOMAIN"].presence || application_host
  mailgun_api_key = ENV["MAILGUN_API_KEY"]
  mailgun_api_host = ENV.fetch("MAILGUN_API_HOST", "api.eu.mailgun.net")

  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = {
    host: application_host,
    protocol: "https"
  }
  config.action_mailer.asset_host = "https://#{application_host}"
  config.action_mailer.default_options = {
    from: mailer_from_address
  }
  config.action_mailer.delivery_method = :mailgun
  config.action_mailer.mailgun_settings = {
    api_key: mailgun_api_key,
    domain: mailgun_domain,
    api_host: mailgun_api_host
  }.compact

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  config.hosts << ENV["APPLICATION_HOST"] if ENV["APPLICATION_HOST"].present?
  config.hosts << /.*\.local/ # Allow home network .local domains for HA
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end

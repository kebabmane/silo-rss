ENV["RAILS_ENV"] ||= "test"

# SimpleCov must be loaded before application code
require "simplecov"
SimpleCov.start "rails" do
  add_filter "/test/"
  add_filter "/config/"
  add_filter "/vendor/"

  add_group "Models", "app/models"
  add_group "Controllers", "app/controllers"
  add_group "Services", "app/services"
  add_group "Jobs", "app/jobs"
  add_group "Mailers", "app/mailers"
end

require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require "mocha/minitest"

# Disable external HTTP requests during tests
WebMock.disable_net_connect!(allow_localhost: true)

# Ensure exceptions bubble up in integration/controller tests
Rails.application.env_config["action_dispatch.show_exceptions"] = false
Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Reset Settings between tests to prevent state leakage
    setup do
      Rails.cache.clear
      Setting.require_admin_confirmation = true
    end

    # Add more helper methods to be used by all tests here...

    # Authentication helper for controller tests
    def login_as(user)
      session = user.sessions.create!
      cookies.signed.permanent[:session_id] = { value: session.id, httponly: true }
    end

    # API authentication helper
    def api_login_as(user)
      @current_user = user
    end

    # Set authorization header for API requests
    def api_headers(user)
      { "Authorization" => "Bearer #{user.api_token}" }
    end
  end
end

module ActionDispatch
  class IntegrationTest
    def login_as(user)
      # Integration tests need to POST to session path to properly set cookies
      # All fixture users have password "password"
      post session_path, params: {
        email_address: user.email_address,
        password: "password"
      }, headers: { "User-Agent" => "Test User Agent" }

      # Ensure login succeeded (should redirect to dashboard)
      unless response.redirect? || response.successful?
        raise "Login failed for #{user.email_address}: #{response.status} #{response.body}"
      end

      # Follow redirect to complete the login flow
      follow_redirect! if response.redirect?
    end

    def api_headers(user)
      { "Authorization" => "Bearer #{user.api_token}" }
    end
  end
end

module ActionController
  class TestCase
    def login_as(user)
      session = user.sessions.create!
      cookies.signed[:session_id] = session.id
    end
  end
end

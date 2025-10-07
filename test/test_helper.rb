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

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

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
      session = user.sessions.create!
      cookies.signed[:session_id] = session.id
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

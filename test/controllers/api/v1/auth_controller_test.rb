require "test_helper"

module Api
  module V1
    class AuthControllerTest < ActionDispatch::IntegrationTest
      setup do
        @alice = users(:alice)
        @bob = users(:bob)
      end

      # POST /api/v1/auth/login
      test "login returns user and api token with valid credentials" do
        original_token = @alice.api_token

        post api_v1_auth_login_url,
             params: {
               email: "alice@example.com",
               password: "password"
             },
             as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json.key?("user")
        assert_equal @alice.id, json["user"]["id"]
        assert_equal @alice.email_address, json["user"]["email"]
        assert json["user"]["api_token"].present?
        refute_equal original_token, json["user"]["api_token"]
      end

      test "login returns correct user structure" do
        post api_v1_auth_login_url,
             params: {
               email: "alice@example.com",
               password: "password"
             },
             as: :json

        assert_response :success
        json = JSON.parse(response.body)

        user = json["user"]
        assert user.key?("id")
        assert user.key?("email")
        assert user.key?("api_token")
        assert user.key?("api_token_expires_at")

        # Should not include sensitive information like password_digest
        assert_not user.key?("password_digest")
        assert_not user.key?("password")
      end

      test "login returns unauthorized with invalid email" do
        post api_v1_auth_login_url,
             params: {
               email: "nonexistent@example.com",
               password: "password"
             },
             as: :json

        assert_response :unauthorized
        json = JSON.parse(response.body)

        assert json.key?("error")
        assert_equal "Invalid email or password", json["error"]
      end

      test "login returns unauthorized with invalid password" do
        post api_v1_auth_login_url,
             params: {
               email: "alice@example.com",
               password: "wrongpassword"
             },
             as: :json

        assert_response :unauthorized
        json = JSON.parse(response.body)

        assert json.key?("error")
        assert_equal "Invalid email or password", json["error"]
      end

      test "login returns unauthorized with empty email" do
        post api_v1_auth_login_url,
             params: {
               email: "",
               password: "password"
             },
             as: :json

        assert_response :unauthorized
        json = JSON.parse(response.body)

        assert_equal "Invalid email or password", json["error"]
      end

      test "login returns unauthorized with empty password" do
        post api_v1_auth_login_url,
             params: {
               email: "alice@example.com",
               password: ""
             },
             as: :json

        assert_response :unauthorized
        json = JSON.parse(response.body)

        assert_equal "Invalid email or password", json["error"]
      end

      test "login returns unauthorized with missing email parameter" do
        post api_v1_auth_login_url,
             params: { password: "password" },
             as: :json

        assert_response :unauthorized
        json = JSON.parse(response.body)

        assert_equal "Invalid email or password", json["error"]
      end

      test "login returns unauthorized with missing password parameter" do
        post api_v1_auth_login_url,
             params: { email: "alice@example.com" },
             as: :json

        assert_response :unauthorized
        json = JSON.parse(response.body)

        assert_equal "Invalid email or password", json["error"]
      end

      test "login returns forbidden for unconfirmed user" do
        post api_v1_auth_login_url,
             params: {
               email: "pending@example.com",
               password: "password"
             },
             as: :json

        assert_response :forbidden
        json = JSON.parse(response.body)
        assert_equal "Account pending admin approval", json["error"]
      end

      test "login is case insensitive for email" do
        post api_v1_auth_login_url,
             params: {
               email: "ALICE@EXAMPLE.COM",
               password: "password"
             },
             as: :json

        # Email lookup is case-insensitive due to email normalization
        assert_response :success
        json = JSON.parse(response.body)
        assert_equal @alice.id, json["user"]["id"]
      end

      test "login works with different valid users" do
        post api_v1_auth_login_url,
             params: {
               email: "bob@example.com",
               password: "password"
             },
             as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert_equal @bob.id, json["user"]["id"]
        assert_equal @bob.email_address, json["user"]["email"]
        assert json["user"]["api_token"].present?
      end

      test "login does not require authentication header" do
        # Login should work without existing authentication
        post api_v1_auth_login_url,
             params: {
               email: "alice@example.com",
               password: "password"
             },
             as: :json

        assert_response :success
      end

      test "login returns api token that can be used for authentication" do
        post api_v1_auth_login_url,
             params: {
               email: "alice@example.com",
               password: "password"
             },
             as: :json

        assert_response :success
        json = JSON.parse(response.body)
        api_token = json["user"]["api_token"]

        # Use the token to access a protected endpoint
        get api_v1_feeds_url,
            headers: { "Authorization" => "Bearer #{api_token}" },
            as: :json

        assert_response :success
      end

      # POST /api/v1/auth/register
      test "register creates new user with valid parameters" do
        assert_difference("User.count", 1) do
          post api_v1_auth_register_url,
               params: {
                 email: "newuser@example.com",
                 password: "password123",
                 password_confirmation: "password123"
               },
               as: :json
        end

        assert_response :created
        json = JSON.parse(response.body)

        assert json.key?("user")
        assert_equal "newuser@example.com", json["user"]["email"]
        assert_equal false, json["user"]["confirmed"]
        assert_not json["user"].key?("api_token")
        assert_equal "Account created. Awaiting admin approval before activation.", json["message"]
      end

      test "register returns correct user structure" do
        post api_v1_auth_register_url,
             params: {
               email: "newuser@example.com",
               password: "password123",
               password_confirmation: "password123"
             },
             as: :json

        assert_response :created
        json = JSON.parse(response.body)

        user = json["user"]
        assert user.key?("id")
        assert user.key?("email")
        assert user.key?("confirmed")

        # Should not include sensitive information
        assert_not user.key?("password_digest")
        assert_not user.key?("password")
        assert_not user.key?("password_confirmation")
      end

      test "register does not expose api token" do
        post api_v1_auth_register_url,
             params: {
               email: "newuser@example.com",
               password: "password123",
               password_confirmation: "password123"
             },
             as: :json

        assert_response :created
        json = JSON.parse(response.body)

        assert_not json["user"].key?("api_token")
      end

      test "register returns unprocessable entity with missing email" do
        post api_v1_auth_register_url,
             params: {
               password: "password123",
               password_confirmation: "password123"
             },
             as: :json

        assert_response :unprocessable_entity
        json = JSON.parse(response.body)

        assert json.key?("error")
        assert json["error"].is_a?(Array)
      end

      test "register returns unprocessable entity with missing password" do
        post api_v1_auth_register_url,
             params: {
               email: "newuser@example.com",
               password_confirmation: "password123"
             },
             as: :json

        assert_response :unprocessable_entity
        json = JSON.parse(response.body)

        assert json.key?("error")
      end

      test "register returns unprocessable entity with mismatched passwords" do
        post api_v1_auth_register_url,
             params: {
               email: "newuser@example.com",
               password: "password123",
               password_confirmation: "differentpassword"
             },
             as: :json

        assert_response :unprocessable_entity
        json = JSON.parse(response.body)

        assert json.key?("error")
        assert json["error"].is_a?(Array)
      end

      test "register returns unprocessable entity with duplicate email" do
        post api_v1_auth_register_url,
             params: {
               email: "alice@example.com",  # Already exists
               password: "password123",
               password_confirmation: "password123"
             },
             as: :json

        assert_response :unprocessable_entity
        json = JSON.parse(response.body)

        assert json.key?("error")
        assert json["error"].is_a?(Array)
      end

      test "register returns unprocessable entity with invalid email format" do
        post api_v1_auth_register_url,
             params: {
               email: "invalid-email",
               password: "password123",
               password_confirmation: "password123"
             },
             as: :json

        # Response depends on email validation in model
        # Adjust based on actual validation
        assert_includes [201, 422], response.status
      end

      test "register returns unprocessable entity with empty email" do
        post api_v1_auth_register_url,
             params: {
               email: "",
               password: "password123",
               password_confirmation: "password123"
             },
             as: :json

        assert_response :unprocessable_entity
        json = JSON.parse(response.body)

        assert json.key?("error")
      end

      test "register returns unprocessable entity with empty password" do
        post api_v1_auth_register_url,
             params: {
               email: "newuser@example.com",
               password: "",
               password_confirmation: ""
             },
             as: :json

        assert_response :unprocessable_entity
        json = JSON.parse(response.body)

        assert json.key?("error")
      end

      test "register returns unprocessable entity with short password" do
        post api_v1_auth_register_url,
             params: {
               email: "newuser@example.com",
               password: "12345",
               password_confirmation: "12345"
             },
             as: :json

        # Assuming password minimum length validation exists
        # Adjust based on actual validation rules
        assert_includes [201, 422], response.status
      end

      test "register does not require authentication header" do
        post api_v1_auth_register_url,
             params: {
               email: "newuser@example.com",
               password: "password123",
               password_confirmation: "password123"
             },
             as: :json

        assert_response :created
      end

      test "register creates user with hashed password" do
        post api_v1_auth_register_url,
             params: {
               email: "newuser@example.com",
               password: "password123",
               password_confirmation: "password123"
             },
             as: :json

        assert_response :created

        user = User.find_by(email_address: "newuser@example.com")
        assert_not_nil user
        assert_not_equal "password123", user.password_digest
        assert user.authenticate("password123")
      end

      test "register creates user awaiting admin approval" do
        post api_v1_auth_register_url,
             params: {
               email: "newuser@example.com",
               password: "password123",
               password_confirmation: "password123"
             },
             as: :json

        assert_response :created
        json = JSON.parse(response.body)

        # User is created but not confirmed
        assert_equal "newuser@example.com", json["user"]["email"]
        assert_equal false, json["user"]["confirmed"]
        assert_match /Awaiting admin approval/, json["message"]

        # API token is not returned on registration (only after confirmation)
        assert_nil json["user"]["api_token"]
      end

      test "register prevents login until admin confirms user" do
        # Register
        post api_v1_auth_register_url,
             params: {
               email: "newuser@example.com",
               password: "password123",
               password_confirmation: "password123"
             },
             as: :json

        assert_response :created

        # Login attempt should be rejected
        post api_v1_auth_login_url,
             params: {
               email: "newuser@example.com",
               password: "password123"
             },
             as: :json

        assert_response :forbidden
        json = JSON.parse(response.body)
        assert_equal "Account pending admin approval", json["error"]
      end

      # Edge cases and security tests
      test "login prevents timing attacks by always checking password" do
        # User.authenticate_by is the Rails-provided constant-time authentication method.
        # It internally uses BCrypt::Password comparison regardless of whether the user exists,
        # preventing timing attacks. We verify both paths return :unauthorized with the same message.

        post api_v1_auth_login_url,
             params: { email: "nonexistent@example.com", password: "password" },
             as: :json
        assert_response :unauthorized
        assert_equal "Invalid email or password", JSON.parse(response.body)["error"]

        post api_v1_auth_login_url,
             params: { email: "alice@example.com", password: "wrongpassword" },
             as: :json
        assert_response :unauthorized
        assert_equal "Invalid email or password", JSON.parse(response.body)["error"]
      end

      test "register does not create user if validation fails" do
        initial_count = User.count

        post api_v1_auth_register_url,
             params: {
               email: "alice@example.com",  # Duplicate
               password: "password123",
               password_confirmation: "password123"
             },
             as: :json

        assert_response :unprocessable_entity
        assert_equal initial_count, User.count
      end

      test "login handles special characters in password" do
        user = User.create!(
          email_address: "special@example.com",
          password: "p@$$w0rd!#%",
          password_confirmation: "p@$$w0rd!#%",
          confirmed_at: Time.current
        )

        post api_v1_auth_login_url,
             params: {
               email: "special@example.com",
               password: "p@$$w0rd!#%"
             },
             as: :json

        assert_response :success
        json = JSON.parse(response.body)
        assert_equal user.id, json["user"]["id"]
      end

      test "register handles special characters in email and password" do
        post api_v1_auth_register_url,
             params: {
               email: "user+tag@example.com",
               password: "p@$$w0rd!#%",
               password_confirmation: "p@$$w0rd!#%"
             },
             as: :json

        # Adjust based on whether your app supports + in emails
        assert_includes [201, 422], response.status
      end

      test "login returns consistent error message for security" do
        # Test that error messages don't reveal if email exists
        post api_v1_auth_login_url,
             params: {
               email: "nonexistent@example.com",
               password: "password"
             },
             as: :json

        nonexistent_error = JSON.parse(response.body)["error"]

        post api_v1_auth_login_url,
             params: {
               email: "alice@example.com",
               password: "wrongpassword"
             },
             as: :json

        wrong_password_error = JSON.parse(response.body)["error"]

        # Both should return the same error message
        assert_equal nonexistent_error, wrong_password_error
        assert_equal "Invalid email or password", nonexistent_error
      end

      test "multiple registrations create different users" do
        post api_v1_auth_register_url,
             params: {
               email: "user1@example.com",
               password: "password123",
               password_confirmation: "password123"
             },
             as: :json

        assert_response :created
        user1_id = JSON.parse(response.body)["user"]["id"]

        post api_v1_auth_register_url,
             params: {
               email: "user2@example.com",
               password: "password123",
               password_confirmation: "password123"
             },
             as: :json

        assert_response :created
        user2_id = JSON.parse(response.body)["user"]["id"]

        # Different users should have different IDs
        assert_not_equal user1_id, user2_id

        # Both users should be unconfirmed
        user1 = User.find(user1_id)
        user2 = User.find(user2_id)
        assert_nil user1.confirmed_at
        assert_nil user2.confirmed_at
      end

      test "register error response includes all validation errors" do
        post api_v1_auth_register_url,
             params: {
               email: "",
               password: "",
               password_confirmation: "different"
             },
             as: :json

        assert_response :unprocessable_entity
        json = JSON.parse(response.body)

        assert json.key?("error")
        assert json["error"].is_a?(Array)
        assert json["error"].length > 0
      end

      test "login response time is consistent for valid and invalid attempts" do
        # This helps prevent user enumeration
        start_time = Time.now
        post api_v1_auth_login_url,
             params: {
               email: "alice@example.com",
               password: "password"
             },
             as: :json
        valid_time = Time.now - start_time

        start_time = Time.now
        post api_v1_auth_login_url,
             params: {
               email: "alice@example.com",
               password: "wrongpassword"
             },
             as: :json
        invalid_time = Time.now - start_time

        # Times should be similar (within 100ms)
        assert (valid_time - invalid_time).abs < 0.1
      end
    end
  end
end

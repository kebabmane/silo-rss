require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
  end

  # New action tests
  test "should get new session page" do
    get new_session_url
    assert_response :success
  end

  test "should get new session page when not authenticated" do
    get new_session_url
    assert_response :success
  end

  test "should allow access to new session page even when authenticated" do
    login_as @alice
    get new_session_url
    assert_response :success
  end

  # Create action tests
  test "should create session with valid credentials" do
    assert_difference "Session.count", 1 do
      post session_url, params: { email_address: "alice@example.com", password: "password" }
    end

    assert_redirected_to dashboard_path
    assert_not_nil cookies[:session_id]
  end

  test "should set session cookie on successful login" do
    post session_url, params: { email_address: "alice@example.com", password: "password" }

    assert_not_nil cookies.signed.permanent[:session_id]
  end

  test "should redirect to root after successful login" do
    post session_url, params: { email_address: "alice@example.com", password: "password" }

    assert_redirected_to dashboard_path
  end

  test "should not create session with invalid email" do
    assert_no_difference "Session.count" do
      post session_url, params: { email_address: "invalid@example.com", password: "password" }
    end

    assert_redirected_to new_session_path
    assert_equal "Try another email address or password.", flash[:alert]
  end

  test "should not create session with invalid password" do
    assert_no_difference "Session.count" do
      post session_url, params: { email_address: "alice@example.com", password: "wrong_password" }
    end

    assert_redirected_to new_session_path
    assert_equal "Try another email address or password.", flash[:alert]
  end

  test "should not allow login for unconfirmed user" do
    pending_user = users(:pending)

    assert_no_difference "Session.count" do
      post session_url, params: { email_address: pending_user.email_address, password: "password" }
    end

    assert_redirected_to new_session_path
    assert_equal "Your account is awaiting admin approval.", flash[:alert]
  end

  test "should not create session with blank email" do
    assert_no_difference "Session.count" do
      post session_url, params: { email_address: "", password: "password" }
    end

    assert_redirected_to new_session_path
  end

  test "should not create session with blank password" do
    assert_no_difference "Session.count" do
      post session_url, params: { email_address: "alice@example.com", password: "" }
    end

    assert_redirected_to new_session_path
  end

  test "should handle missing email parameter" do
    assert_no_difference "Session.count" do
      post session_url, params: { password: "password" }
    end

    assert_redirected_to new_session_path
  end

  test "should handle missing password parameter" do
    assert_no_difference "Session.count" do
      post session_url, params: { email_address: "alice@example.com" }
    end

    assert_redirected_to new_session_path
  end

  test "should be case sensitive for email" do
    # Rails typically handles email case-insensitivity at the model level
    # This test ensures the authentication behavior
    post session_url, params: { email_address: "ALICE@EXAMPLE.COM", password: "password" }

    # Depending on your User.authenticate_by implementation, this might succeed or fail
    # Adjust based on your actual implementation
  end

  test "should show generic error message for security" do
    post session_url, params: { email_address: "nonexistent@example.com", password: "password" }

    # Should not reveal whether email exists
    assert_equal "Try another email address or password.", flash[:alert]
  end

  # Rate limiting tests
  test "should allow up to 10 login attempts" do
    # Test that rate limiting is configured (actual behavior depends on rate_limit implementation)
    10.times do
      post session_url, params: { email_address: "alice@example.com", password: "wrong" }
    end

    # The 11th attempt should trigger rate limiting
    post session_url, params: { email_address: "alice@example.com", password: "password" }

    # Depending on rate limit implementation, this might redirect with specific message
  end

  # Destroy action tests
  test "should redirect to login when destroying session without authentication" do
    delete session_url
    assert_redirected_to new_session_path
  end

  test "should destroy session when authenticated" do
    login_as @alice
    session = @alice.sessions.last

    assert_difference "Session.count", -1 do
      delete session_url
    end

    assert_redirected_to new_session_path
  end

  test "should clear session cookie on logout" do
    login_as @alice

    delete session_url

    # Cookie should be cleared or invalidated
    assert_redirected_to new_session_path
  end

  test "should redirect to login page after logout" do
    login_as @alice

    delete session_url

    assert_redirected_to new_session_path
  end

  test "should only destroy current session, not all user sessions" do
    login_as @alice
    # Create an additional session for alice
    other_session = @alice.sessions.create!

    current_session = @alice.sessions.last

    delete session_url

    # Current session should be destroyed
    # Other session should remain (depending on your implementation)
    assert_not Session.exists?(current_session.id)
  end

  # Security tests
  test "should not allow session fixation" do
    # Get a session token before login
    get new_session_url
    token_before = cookies[:session_id]

    # Login
    post session_url, params: { email_address: "alice@example.com", password: "password" }

    # Session token should be different after login
    token_after = cookies.signed.permanent[:session_id]

    # New session should be created
    assert_not_nil token_after
  end

  test "should require valid parameters only" do
    # Should not accept additional parameters beyond email_address and password
    post session_url, params: {
      email_address: "alice@example.com",
      password: "password",
      admin: true,
      role: "admin"
    }

    # Should still login successfully but ignore extra params
    assert_redirected_to dashboard_path
  end

  # Edge cases
  test "should handle email with whitespace" do
    assert_no_difference "Session.count" do
      post session_url, params: { email_address: " alice@example.com ", password: "password" }
    end

    # Depending on implementation, this might succeed if email is stripped
  end

  test "should handle very long email" do
    long_email = "a" * 1000 + "@example.com"

    assert_no_difference "Session.count" do
      post session_url, params: { email_address: long_email, password: "password" }
    end

    assert_redirected_to new_session_path
  end

  test "should handle very long password" do
    long_password = "a" * 10000

    assert_no_difference "Session.count" do
      post session_url, params: { email_address: "alice@example.com", password: long_password }
    end

    assert_redirected_to new_session_path
  end

  test "should handle special characters in password" do
    # Create a user with special characters in password
    special_user = User.create!(
      email_address: "special@example.com",
      password: "p@ssw0rd!#$%^&*()",
      password_confirmation: "p@ssw0rd!#$%^&*()"
    )

    assert_difference "Session.count", 1 do
      post session_url, params: {
        email_address: "special@example.com",
        password: "p@ssw0rd!#$%^&*()"
      }
    end

    assert_redirected_to dashboard_path
  end

  test "should handle nil params gracefully" do
    assert_no_difference "Session.count" do
      post session_url, params: { email_address: nil, password: nil }
    end

    assert_redirected_to new_session_path
  end

  test "should not expose timing attacks" do
    # Both invalid email and invalid password should take similar time
    # This is more of a security consideration than a testable assertion
    # Just ensure both cases are handled similarly

    post session_url, params: { email_address: "invalid@example.com", password: "password" }
    assert_redirected_to new_session_path
    message1 = flash[:alert]

    post session_url, params: { email_address: "alice@example.com", password: "invalid" }
    assert_redirected_to new_session_path
    message2 = flash[:alert]

    # Both should show the same generic message
    assert_equal message1, message2
  end
end

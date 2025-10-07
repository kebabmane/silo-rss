require "test_helper"

class UserAuthenticationFlowTest < ActionDispatch::IntegrationTest
  test "complete user registration flow" do
    # Visit registration page
    get new_registration_path
    assert_response :success

    # Submit registration form with valid data
    assert_difference "User.count", 1 do
      assert_difference "Session.count", 1 do
        post registrations_path, params: {
          user: {
            email_address: "newuser@example.com",
            password: "securepassword123",
            password_confirmation: "securepassword123"
          }
        }
      end
    end

    # Should redirect to dashboard after successful registration
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success

    # Should display success message
    assert_match /Welcome! Your account has been created/, flash[:notice]

    # User should be logged in (session cookie set)
    assert_not_nil cookies[:session_id]

    # Verify user was created with correct attributes
    user = User.find_by(email_address: "newuser@example.com")
    assert user
    assert user.authenticate("securepassword123")
    assert user.api_token.present?
  end

  test "registration with invalid data shows errors" do
    # Visit registration page
    get new_registration_path
    assert_response :success

    # Submit registration with mismatched passwords
    assert_no_difference "User.count" do
      post registrations_path, params: {
        user: {
          email_address: "newuser@example.com",
          password: "password123",
          password_confirmation: "different_password"
        }
      }
    end

    # Should re-render form with errors
    assert_response :unprocessable_entity
    assert_select "form"
  end

  test "registration with existing email shows errors" do
    # Use existing user from fixtures
    existing_email = users(:alice).email_address

    assert_no_difference "User.count" do
      post registrations_path, params: {
        user: {
          email_address: existing_email,
          password: "password123",
          password_confirmation: "password123"
        }
      }
    end

    assert_response :unprocessable_entity
  end

  test "complete login flow with valid credentials" do
    user = users(:alice)

    # Visit login page
    get new_session_path
    assert_response :success

    # Submit login form
    assert_difference "Session.count", 1 do
      post session_path, params: {
        email_address: user.email_address,
        password: "password"  # From fixtures
      }
    end

    # Should redirect to dashboard after successful login
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success

    # Session cookie should be set
    assert_not_nil cookies[:session_id]

    # Verify session was created for the user
    assert user.sessions.exists?
  end

  test "login with invalid credentials shows error" do
    get new_session_path
    assert_response :success

    assert_no_difference "Session.count" do
      post session_path, params: {
        email_address: "alice@example.com",
        password: "wrong_password"
      }
    end

    # Should redirect back to login with error
    assert_redirected_to new_session_path
    follow_redirect!
    assert_match /Try another email address or password/, flash[:alert]
  end

  test "login with non-existent email shows error" do
    get new_session_path

    assert_no_difference "Session.count" do
      post session_path, params: {
        email_address: "nonexistent@example.com",
        password: "password"
      }
    end

    assert_redirected_to new_session_path
    follow_redirect!
    assert_match /Try another email address or password/, flash[:alert]
  end

  test "logout destroys session" do
    user = users(:alice)
    session = user.sessions.create!(user_agent: "Test", ip_address: "127.0.0.1")
    cookies.signed.permanent[:session_id] = { value: session.id, httponly: true }

    # Verify user is logged in
    get dashboard_path
    assert_response :success

    # Logout
    assert_difference "Session.count", -1 do
      delete session_path
    end

    # Should redirect to login page
    assert_redirected_to new_session_path

    # Session should be destroyed
    assert_not Session.exists?(session.id)

    # Cookie should be deleted
    follow_redirect!
    assert_nil cookies[:session_id]
  end

  test "authentication required for protected pages" do
    # Try to access dashboard without authentication
    get dashboard_path

    # Should redirect to login page
    assert_redirected_to new_session_path
  end

  test "redirect to intended page after login" do
    # Try to access feeds page without authentication
    get feeds_path
    assert_redirected_to new_session_path

    # The return_to URL should be stored in session
    # Now login
    user = users(:alice)
    post session_path, params: {
      email_address: user.email_address,
      password: "password"
    }

    # Should redirect back to originally requested page
    assert_redirected_to feeds_path
  end

  test "complete user journey: register, logout, login" do
    # Step 1: Register new user
    post registrations_path, params: {
      user: {
        email_address: "journey@example.com",
        password: "mypassword123",
        password_confirmation: "mypassword123"
      }
    }

    assert_redirected_to dashboard_path
    user = User.find_by(email_address: "journey@example.com")
    assert user

    # Step 2: Logout
    delete session_path
    assert_redirected_to new_session_path

    # Step 3: Try to access protected page
    get dashboard_path
    assert_redirected_to new_session_path

    # Step 4: Login again
    post session_path, params: {
      email_address: "journey@example.com",
      password: "mypassword123"
    }

    assert_redirected_to dashboard_path
    follow_redirect!
    assert_response :success
  end

  test "email normalization during registration" do
    # Register with email containing uppercase and spaces
    post registrations_path, params: {
      user: {
        email_address: "  NewUser@EXAMPLE.COM  ",
        password: "password123",
        password_confirmation: "password123"
      }
    }

    user = User.find_by(email_address: "newuser@example.com")
    assert user, "User should be created with normalized email"
  end

  test "multiple sessions for same user" do
    user = users(:alice)

    # First login (simulating desktop browser)
    post session_path, params: {
      email_address: user.email_address,
      password: "password"
    }

    assert_redirected_to dashboard_path
    first_session_cookie = cookies[:session_id]

    # Clear cookies (simulating different browser)
    cookies.clear

    # Second login (simulating mobile browser)
    post session_path, params: {
      email_address: user.email_address,
      password: "password"
    }

    assert_redirected_to dashboard_path
    second_session_cookie = cookies[:session_id]

    # Both sessions should exist
    assert_not_equal first_session_cookie, second_session_cookie
    assert_equal 2, user.sessions.count
  end
end

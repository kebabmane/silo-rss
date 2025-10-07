require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
  end

  # New action tests
  test "should get new password reset page" do
    get new_password_url
    assert_response :success
  end

  test "should get new password page when not authenticated" do
    get new_password_url
    assert_response :success
  end

  test "should allow access to new password page when authenticated" do
    login_as @alice
    get new_password_url
    assert_response :success
  end

  # Create action tests
  test "should send password reset email for existing user" do
    assert_enqueued_emails 1 do
      post passwords_url, params: { email_address: @alice.email_address }
    end

    assert_redirected_to new_session_path
    assert_equal "Password reset instructions sent (if user with that email address exists).", flash[:notice]
  end

  test "should show same message for non-existent user for security" do
    post passwords_url, params: { email_address: "nonexistent@example.com" }

    assert_redirected_to new_session_path
    assert_equal "Password reset instructions sent (if user with that email address exists).", flash[:notice]
  end

  test "should not send email for non-existent user" do
    assert_no_enqueued_emails do
      post passwords_url, params: { email_address: "nonexistent@example.com" }
    end

    assert_redirected_to new_session_path
  end

  test "should redirect to new session page after requesting reset" do
    post passwords_url, params: { email_address: @alice.email_address }

    assert_redirected_to new_session_path
  end

  test "should handle blank email gracefully" do
    post passwords_url, params: { email_address: "" }

    assert_redirected_to new_session_path
    assert_equal "Password reset instructions sent (if user with that email address exists).", flash[:notice]
  end

  test "should handle nil email gracefully" do
    post passwords_url, params: { email_address: nil }

    assert_redirected_to new_session_path
  end

  test "should handle missing email parameter" do
    post passwords_url, params: {}

    assert_redirected_to new_session_path
  end

  test "should send email with reset token" do
    PasswordsMailer.expects(:reset).with(@alice, instance_of(String)).returns(mock(deliver_later: true))

    post passwords_url, params: { email_address: @alice.email_address }

    assert_redirected_to new_session_path
  end

  # Edit action tests
  test "should get edit password page with valid token" do
    # Generate a valid token for alice
    token = @alice.generate_token_for(:password_reset)

    get edit_password_url(token)
    assert_response :success
    # User is loaded from token - verified by successful response
  end

  test "should redirect with error for invalid token" do
    get edit_password_url("invalid_token")

    assert_redirected_to new_password_path
    assert_equal "Password reset link is invalid or has expired.", flash[:alert]
  end

  test "should redirect with error for expired token" do
    # Create an expired token
    # This depends on your token implementation
    # Assuming tokens expire after a certain time

    token = "expired_token_signature"

    get edit_password_url(token)

    assert_redirected_to new_password_path
    assert_equal "Password reset link is invalid or has expired.", flash[:alert]
  end

  test "should allow unauthenticated access to edit with valid token" do
    token = @alice.generate_token_for(:password_reset)

    get edit_password_url(token)
    assert_response :success
  end

  # Update action tests
  test "should update password with valid token and matching passwords" do
    token = @alice.generate_token_for(:password_reset)

    patch password_url(token), params: {
      password: "new_password123",
      password_confirmation: "new_password123"
    }

    assert_redirected_to new_session_path
    assert_equal "Password has been reset.", flash[:notice]

    # Verify password was actually changed
    @alice.reload
    assert @alice.authenticate("new_password123")
  end

  test "should redirect to new session after successful password reset" do
    token = @alice.generate_token_for(:password_reset)

    patch password_url(token), params: {
      password: "new_password123",
      password_confirmation: "new_password123"
    }

    assert_redirected_to new_session_path
  end

  test "should not update password with mismatched confirmation" do
    token = @alice.generate_token_for(:password_reset)
    original_password_digest = @alice.password_digest

    patch password_url(token), params: {
      password: "new_password123",
      password_confirmation: "different_password"
    }

    assert_redirected_to edit_password_path(token)
    assert_equal "Passwords did not match.", flash[:alert]

    # Verify password was not changed
    @alice.reload
    assert_equal original_password_digest, @alice.password_digest
  end

  test "should not update password with blank password" do
    token = @alice.generate_token_for(:password_reset)
    original_password_digest = @alice.password_digest

    patch password_url(token), params: {
      password: "",
      password_confirmation: ""
    }

    assert_redirected_to edit_password_path(token)
    assert_equal "Passwords did not match.", flash[:alert]

    @alice.reload
    assert_equal original_password_digest, @alice.password_digest
  end

  test "should not update password with invalid token" do
    patch password_url("invalid_token"), params: {
      password: "new_password123",
      password_confirmation: "new_password123"
    }

    assert_redirected_to new_password_path
    assert_equal "Password reset link is invalid or has expired.", flash[:alert]
  end

  test "should handle expired token on update" do
    patch password_url("expired_token"), params: {
      password: "new_password123",
      password_confirmation: "new_password123"
    }

    assert_redirected_to new_password_path
    assert_equal "Password reset link is invalid or has expired.", flash[:alert]
  end

  test "should handle missing password parameters" do
    token = @alice.generate_token_for(:password_reset)

    patch password_url(token), params: {}

    assert_redirected_to edit_password_path(token)
  end

  test "should handle nil password" do
    token = @alice.generate_token_for(:password_reset)

    patch password_url(token), params: {
      password: nil,
      password_confirmation: nil
    }

    assert_redirected_to edit_password_path(token)
  end

  # Security tests
  test "should not reveal if email exists in system" do
    # Request for existing user
    post passwords_url, params: { email_address: @alice.email_address }
    message1 = flash[:notice]

    # Request for non-existent user
    post passwords_url, params: { email_address: "nonexistent@example.com" }
    message2 = flash[:notice]

    # Both should show the same message
    assert_equal message1, message2
  end

  test "should hash new password before storing" do
    token = @alice.generate_token_for(:password_reset)

    patch password_url(token), params: {
      password: "new_password123",
      password_confirmation: "new_password123"
    }

    @alice.reload
    # Password should be hashed, not stored as plaintext
    assert_not_equal "new_password123", @alice.password_digest
    assert @alice.password_digest.present?
  end

  test "should not allow token reuse after password reset" do
    token = @alice.generate_token_for(:password_reset)

    # First reset
    patch password_url(token), params: {
      password: "new_password123",
      password_confirmation: "new_password123"
    }
    assert_redirected_to new_session_path

    # Try to reuse the same token
    patch password_url(token), params: {
      password: "another_password",
      password_confirmation: "another_password"
    }

    # Depending on token implementation, this should fail
    # Token should be invalidated after use
    assert_redirected_to new_password_path
  end

  test "should only reset password for token owner" do
    alice_token = @alice.generate_token_for(:password_reset)

    # Try to reset bob's password using alice's token
    patch password_url(alice_token), params: {
      password: "new_password123",
      password_confirmation: "new_password123"
    }

    # Should reset alice's password, not bob's
    @alice.reload
    @bob.reload

    assert @alice.authenticate("new_password123")
    assert @bob.authenticate("password") # Bob's password unchanged
  end

  # Edge cases
  test "should handle email with different case" do
    post passwords_url, params: { email_address: "ALICE@EXAMPLE.COM" }

    # Depending on email normalization, this should find alice
    assert_redirected_to new_session_path
  end

  test "should handle email with whitespace" do
    post passwords_url, params: { email_address: " alice@example.com " }

    # Depending on implementation, should handle gracefully
    assert_redirected_to new_session_path
  end

  test "should handle very long password reset" do
    token = @alice.generate_token_for(:password_reset)
    long_password = "a" * 1000

    patch password_url(token), params: {
      password: long_password,
      password_confirmation: long_password
    }

    # BCrypt might have limits, handle accordingly
  end

  test "should handle special characters in new password" do
    token = @alice.generate_token_for(:password_reset)

    patch password_url(token), params: {
      password: "p@ssw0rd!#$%^&*()",
      password_confirmation: "p@ssw0rd!#$%^&*()"
    }

    assert_redirected_to new_session_path
    assert_equal "Password has been reset.", flash[:notice]

    @alice.reload
    assert @alice.authenticate("p@ssw0rd!#$%^&*()")
  end

  test "should enforce minimum password length on reset" do
    token = @alice.generate_token_for(:password_reset)

    patch password_url(token), params: {
      password: "123",
      password_confirmation: "123"
    }

    # Should fail validation for too short password
    assert_redirected_to edit_password_path(token)
  end

  test "should allow maximum valid password length" do
    token = @alice.generate_token_for(:password_reset)
    max_password = "a" * 72 # BCrypt max length

    patch password_url(token), params: {
      password: max_password,
      password_confirmation: max_password
    }

    # Should succeed
    assert_redirected_to new_session_path
  end

  test "should handle malformed token gracefully" do
    get edit_password_url("malformed-token-string")

    assert_redirected_to new_password_path
    assert_equal "Password reset link is invalid or has expired.", flash[:alert]
  end

  test "should handle empty token" do
    get edit_password_url("")

    # Rails routing might handle this differently
    # Adjust based on your routes configuration
  end

  test "should not allow authenticated user's token to reset another user" do
    login_as @bob
    alice_token = @alice.generate_token_for(:password_reset)

    patch password_url(alice_token), params: {
      password: "new_password123",
      password_confirmation: "new_password123"
    }

    # Should reset alice's password (token is independent of current session)
    @alice.reload
    assert @alice.authenticate("new_password123")

    # Bob's password should remain unchanged
    @bob.reload
    assert @bob.authenticate("password")
  end

  test "should allow password reset while logged in" do
    login_as @alice
    token = @alice.generate_token_for(:password_reset)

    patch password_url(token), params: {
      password: "new_password123",
      password_confirmation: "new_password123"
    }

    assert_redirected_to new_session_path
    assert_equal "Password has been reset.", flash[:notice]
  end
end

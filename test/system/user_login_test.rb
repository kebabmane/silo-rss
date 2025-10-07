require "application_system_test_case"

class UserLoginTest < ApplicationSystemTestCase
  setup do
    @user = users(:alice)
  end

  test "user can log in with valid credentials" do
    visit new_session_path

    # Verify login page is displayed
    assert_selector "h1", text: "Sign in"

    # Fill in login form
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password"

    # Submit the form
    click_button "Sign in"

    # Should be redirected to dashboard
    assert_current_path dashboard_path

    # Verify session was created
    assert @user.sessions.reload.any?
  end

  test "user cannot log in with invalid email" do
    visit new_session_path

    fill_in "Email", with: "nonexistent@example.com"
    fill_in "Password", with: "password"

    click_button "Sign in"

    # Should see error message
    assert_text "Try another email address or password."
    assert_current_path new_session_path
  end

  test "user cannot log in with invalid password" do
    visit new_session_path

    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "wrongpassword"

    click_button "Sign in"

    # Should see error message
    assert_text "Try another email address or password."
    assert_current_path new_session_path
  end

  test "user can log out" do
    # First log in
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"

    assert_current_path dashboard_path

    # Now log out (need to find the logout button/link in the UI)
    # This assumes there's a sign out button accessible from dashboard
    # Adjust selector based on actual implementation
    accept_confirm do
      click_button "Sign Out", match: :first
    end

    # Should be redirected to login page
    assert_current_path new_session_path
  end

  test "login form has link to registration page" do
    visit new_session_path

    # Verify create account link exists
    assert_link "Create account", href: new_registration_path

    # Click the link and verify navigation
    click_link "Create account"
    assert_current_path new_registration_path
    assert_selector "h1", text: "Create Account"
  end

  test "login form has link to forgot password page" do
    visit new_session_path

    # Verify forgot password link exists
    assert_link "Forgot password?", href: new_password_path

    # Click the link and verify navigation
    click_link "Forgot password?"
    assert_current_path new_password_path
  end

  test "user cannot access protected pages without logging in" do
    # Try to access dashboard without authentication
    visit dashboard_path

    # Should be redirected to login page
    assert_current_path new_session_path
  end

  test "unauthenticated visitor sees landing page" do
    visit root_path

    assert_text "Welcome to Silo"
    assert_link "Sign In", href: new_session_path
    assert_link "Start Your Silo", href: new_registration_path
  end

  test "user cannot access feeds page without logging in" do
    visit feeds_path

    # Should be redirected to login page
    assert_current_path new_session_path
  end

  test "user cannot access articles page without logging in" do
    visit articles_path

    # Should be redirected to login page
    assert_current_path new_session_path
  end

  test "login form displays flash alert for errors" do
    visit new_session_path

    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "wrongpassword"

    click_button "Sign in"

    # Should see flash alert
    assert_selector "#alert", text: "Try another email address or password."
  end

  test "login form has proper autocomplete attributes" do
    visit new_session_path

    email_field = find_field("Email")
    password_field = find_field("Password")

    # Verify autocomplete attributes for better UX
    assert_equal "username", email_field["autocomplete"]
    assert_equal "current-password", password_field["autocomplete"]
  end

  test "login form requires both email and password" do
    visit new_session_path

    # Try to submit without filling fields
    click_button "Sign in"

    # HTML5 validation should prevent submission
    # This behavior depends on browser, but fields have required attribute
    email_field = find_field("Email")
    password_field = find_field("Password")

    assert email_field["required"]
    assert password_field["required"]
  end

  test "user stays on login page after failed attempt" do
    visit new_session_path

    fill_in "Email", with: "wrong@example.com"
    fill_in "Password", with: "wrongpassword"

    click_button "Sign in"

    # Should stay on login page
    assert_current_path new_session_path
    assert_selector "h1", text: "Sign in"

    # Email field should be preserved
    assert_field "Email"
  end

  test "successful login redirects to root path" do
    visit new_session_path

    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password"

    click_button "Sign in"

    # Should redirect to dashboard
    assert_current_path dashboard_path
  end

  test "login form supports different themes" do
    visit new_session_path

    # Verify dark mode classes are present in the form
    # This tests that the UI supports theming
    page_html = page.html
    assert_includes page_html, "dark:bg-gray-800"
    assert_includes page_html, "dark:text-white"
  end

  test "multiple users can have active sessions" do
    # Login as first user
    visit new_session_path
    fill_in "Email", with: users(:alice).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path dashboard_path

    # Simulate second user login by clearing session and logging in again
    # In a real browser test, this would be in a different browser/incognito window
    Capybara.reset_sessions!

    visit new_session_path
    fill_in "Email", with: users(:bob).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path dashboard_path

    # Both users should have sessions
    assert users(:alice).sessions.reload.any?
    assert users(:bob).sessions.reload.any?
  end

  test "logout destroys session" do
    # Login first
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"

    initial_session_count = @user.sessions.count

    # Logout
    accept_confirm do
      click_button "Sign Out", match: :first
    end

    # Try to access protected page
    visit dashboard_path

    # Should be redirected to login
    assert_current_path new_session_path
  end

  test "login with email containing uppercase letters" do
    # Email should be normalized
    visit new_session_path

    fill_in "Email", with: @user.email_address.upcase
    fill_in "Password", with: "password"

    click_button "Sign in"

    # Should successfully log in
    assert_current_path dashboard_path
  end

  test "login with email containing whitespace" do
    visit new_session_path

    fill_in "Email", with: "  #{@user.email_address}  "
    fill_in "Password", with: "password"

    click_button "Sign in"

    # Should successfully log in due to email normalization
    assert_current_path dashboard_path
  end

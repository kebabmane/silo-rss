require "application_system_test_case"

class UserRegistrationTest < ApplicationSystemTestCase
  test "user can register with valid credentials" do
    visit new_registration_path

    # Verify registration page is displayed
    assert_selector "h1", text: "Create Account"

    # Fill in registration form
    fill_in "Email", with: "newuser@example.com"
    fill_in "Password", with: "securepassword123"
    fill_in "Confirm Password", with: "securepassword123"

    # Submit the form
    click_button "Create Account"

    # Should be redirected to dashboard with welcome message
    assert_text "Welcome! Your account has been created."
    assert_current_path dashboard_path

    # Verify user was created in database
    user = User.find_by(email_address: "newuser@example.com")
    assert_not_nil user
    assert user.authenticate("securepassword123")
  end

  test "user cannot register with invalid email" do
    visit new_registration_path

    fill_in "Email", with: "invalid-email"
    fill_in "Password", with: "securepassword123"
    fill_in "Confirm Password", with: "securepassword123"

    click_button "Create Account"

    # Should see error message
    assert_selector ".bg-red-50", text: "Please fix the following errors:"
    assert_no_text "Welcome! Your account has been created."
  end

  test "user cannot register with short password" do
    visit new_registration_path

    fill_in "Email", with: "newuser@example.com"
    fill_in "Password", with: "short"
    fill_in "Confirm Password", with: "short"

    click_button "Create Account"

    # Should see error message about password length
    assert_selector ".bg-red-50"
    assert_current_path registrations_path
  end

  test "user cannot register with mismatched passwords" do
    visit new_registration_path

    fill_in "Email", with: "newuser@example.com"
    fill_in "Password", with: "securepassword123"
    fill_in "Confirm Password", with: "differentpassword456"

    click_button "Create Account"

    # Should see error message
    assert_selector ".bg-red-50", text: "Please fix the following errors:"
    assert_text "Password confirmation doesn't match Password"
  end

  test "user cannot register with duplicate email" do
    # Use existing user from fixtures
    existing_user = users(:alice)

    visit new_registration_path

    fill_in "Email", with: existing_user.email_address
    fill_in "Password", with: "securepassword123"
    fill_in "Confirm Password", with: "securepassword123"

    click_button "Create Account"

    # Should see error about duplicate email
    assert_selector ".bg-red-50", text: "Please fix the following errors:"
    assert_text "Email address has already been taken"
  end

  test "user cannot register with blank fields" do
    visit new_registration_path

    # Submit form without filling any fields
    click_button "Create Account"

    # Should see error messages
    assert_selector ".bg-red-50", text: "Please fix the following errors:"
    assert_current_path registrations_path
  end

  test "registration form has link to sign in page" do
    visit new_registration_path

    # Verify sign in link exists
    assert_link "Sign in", href: new_session_path

    # Click the link and verify navigation
    click_link "Sign in"
    assert_current_path new_session_path
    assert_selector "h1", text: "Sign in"
  end

  test "email normalization on registration" do
    visit new_registration_path

    # Use email with uppercase and whitespace
    fill_in "Email", with: "  NewUser@EXAMPLE.COM  "
    fill_in "Password", with: "securepassword123"
    fill_in "Confirm Password", with: "securepassword123"

    click_button "Create Account"

    # Should be successful
    assert_text "Welcome! Your account has been created."

    # Verify email was normalized to lowercase and trimmed
    user = User.find_by(email_address: "newuser@example.com")
    assert_not_nil user
  end

  test "registration form displays password requirements" do
    visit new_registration_path

    # Verify password hint is displayed
    assert_text "Minimum 8 characters"

    # Verify form has proper password constraints
    password_field = find_field("Password")
    assert_equal "8", password_field["minlength"]
    assert_equal "72", password_field["maxlength"]
  end

  test "registration form has proper autocomplete attributes" do
    visit new_registration_path

    email_field = find_field("Email")
    password_field = find_field("Password")
    confirmation_field = find_field("Confirm Password")

    # Verify autocomplete attributes for better UX
    assert_equal "username", email_field["autocomplete"]
    assert_equal "new-password", password_field["autocomplete"]
    assert_equal "new-password", confirmation_field["autocomplete"]
  end

  test "user is automatically logged in after registration" do
    visit new_registration_path

    fill_in "Email", with: "autouser@example.com"
    fill_in "Password", with: "securepassword123"
    fill_in "Confirm Password", with: "securepassword123"

    click_button "Create Account"

    # Should be logged in and see authenticated content
    assert_text "Welcome! Your account has been created."
    assert_current_path dashboard_path

    # Verify session was created
    user = User.find_by(email_address: "autouser@example.com")
    assert user.sessions.any?
  end

  test "registration generates API token for user" do
    visit new_registration_path

    fill_in "Email", with: "apiuser@example.com"
    fill_in "Password", with: "securepassword123"
    fill_in "Confirm Password", with: "securepassword123"

    click_button "Create Account"

    # Verify API token was generated
    user = User.find_by(email_address: "apiuser@example.com")
    assert_not_nil user.api_token
    assert user.api_token.length > 0
  end

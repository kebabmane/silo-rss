require "test_helper"

class Admin::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:alice)
    @non_admin = users(:bob)
  end

  # Authorization tests
  test "requires admin authentication for show" do
    login_as @non_admin

    get admin_settings_url

    assert_redirected_to dashboard_path
    assert_equal "Access denied.", flash[:alert]
  end

  test "requires admin authentication for update" do
    login_as @non_admin

    patch admin_settings_url, params: { require_admin_confirmation: "1" }

    assert_redirected_to dashboard_path
    assert_equal "Access denied.", flash[:alert]
  end

  test "redirects to login when not authenticated" do
    get admin_settings_url

    assert_redirected_to new_session_path
  end

  # Show action tests
  test "should get show when admin" do
    login_as @admin

    get admin_settings_url

    assert_response :success
  end

  test "show loads require_admin_confirmation setting" do
    login_as @admin
    Setting.set("require_admin_confirmation", "true")

    get admin_settings_url

    assert_response :success
    # Check that setting is true
    assert Setting.require_admin_confirmation?
  end

  test "show reflects false when setting is false" do
    login_as @admin
    Setting.set("require_admin_confirmation", "false")

    get admin_settings_url

    assert_response :success
    assert_not Setting.require_admin_confirmation?
  end

  test "show reflects false when setting doesn't exist" do
    login_as @admin
    Setting.destroy_all

    get admin_settings_url

    assert_response :success
    assert_not Setting.require_admin_confirmation?
  end

  # Update action tests
  test "should update setting to true when admin" do
    login_as @admin

    patch admin_settings_url, params: { require_admin_confirmation: "1" }

    assert_redirected_to admin_settings_path
    assert_equal "Settings updated successfully.", flash[:notice]
    assert Setting.require_admin_confirmation?
  end

  test "should update setting to false when admin" do
    login_as @admin
    Setting.set("require_admin_confirmation", "true")

    patch admin_settings_url, params: { require_admin_confirmation: "0" }

    assert_redirected_to admin_settings_path
    assert_equal "Settings updated successfully.", flash[:notice]
    assert_not Setting.require_admin_confirmation?
  end

  test "update with 1 sets to true" do
    login_as @admin

    patch admin_settings_url, params: { require_admin_confirmation: "1" }

    assert_equal "true", Setting.get("require_admin_confirmation")
    assert Setting.require_admin_confirmation?
  end

  test "update with 0 sets to false" do
    login_as @admin

    patch admin_settings_url, params: { require_admin_confirmation: "0" }

    assert_equal "false", Setting.get("require_admin_confirmation")
    assert_not Setting.require_admin_confirmation?
  end

  test "update with nil sets to false" do
    login_as @admin

    patch admin_settings_url, params: {}

    assert_not Setting.require_admin_confirmation?
  end

  test "update with empty string sets to false" do
    login_as @admin

    patch admin_settings_url, params: { require_admin_confirmation: "" }

    assert_not Setting.require_admin_confirmation?
  end

  test "update with any non-1 value sets to false" do
    login_as @admin

    patch admin_settings_url, params: { require_admin_confirmation: "true" }
    assert_not Setting.require_admin_confirmation?

    patch admin_settings_url, params: { require_admin_confirmation: "yes" }
    assert_not Setting.require_admin_confirmation?

    patch admin_settings_url, params: { require_admin_confirmation: "2" }
    assert_not Setting.require_admin_confirmation?
  end

  test "update creates setting if it doesn't exist" do
    login_as @admin
    Setting.destroy_all

    assert_difference "Setting.count", 1 do
      patch admin_settings_url, params: { require_admin_confirmation: "1" }
    end

    assert Setting.require_admin_confirmation?
  end

  test "update modifies existing setting" do
    login_as @admin
    Setting.set("require_admin_confirmation", "true")

    assert_no_difference "Setting.count" do
      patch admin_settings_url, params: { require_admin_confirmation: "0" }
    end

    assert_not Setting.require_admin_confirmation?
  end

  test "update is idempotent" do
    login_as @admin

    patch admin_settings_url, params: { require_admin_confirmation: "1" }
    assert Setting.require_admin_confirmation?

    patch admin_settings_url, params: { require_admin_confirmation: "1" }
    assert Setting.require_admin_confirmation?
  end

  # Integration tests
  test "changing setting affects user confirmation flow" do
    login_as @admin

    # Set to true
    patch admin_settings_url, params: { require_admin_confirmation: "1" }
    assert Setting.require_admin_confirmation?

    # Set to false
    patch admin_settings_url, params: { require_admin_confirmation: "0" }
    assert_not Setting.require_admin_confirmation?
  end

  test "setting persists across requests" do
    login_as @admin

    patch admin_settings_url, params: { require_admin_confirmation: "1" }

    # Make a new request
    get admin_settings_url
    assert Setting.require_admin_confirmation?
  end

  # Edge cases
  test "handles malformed parameters" do
    login_as @admin

    patch admin_settings_url, params: { random_param: "value" }

    assert_redirected_to admin_settings_path
    assert_equal "Settings updated successfully.", flash[:notice]
  end

  test "handles multiple rapid updates" do
    login_as @admin

    5.times do |i|
      value = i.even? ? "1" : "0"
      patch admin_settings_url, params: { require_admin_confirmation: value }
      assert_redirected_to admin_settings_path
    end

    # Last iteration is i=4 (even), so value is "1" (true)
    assert Setting.require_admin_confirmation?
  end
end

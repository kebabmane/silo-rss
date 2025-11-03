require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:alice)
  end

  test "requires authentication" do
    get settings_path
    assert_redirected_to new_session_path
  end

  test "renders settings page" do
    login_as(@user)

    get settings_path
    assert_response :success
    assert_select "h1", text: "Settings"
  end

  test "updates time zone" do
    login_as(@user)

    patch settings_path, params: { user: { time_zone: "America/Los_Angeles" } }

    assert_redirected_to settings_path
    assert_equal "Settings updated successfully.", flash[:notice]
    assert_equal "America/Los_Angeles", @user.reload.time_zone
  end

  test "rejects invalid time zone" do
    login_as(@user)

    patch settings_path, params: { user: { time_zone: "Invalid/Zone" } }

    assert_response :unprocessable_entity
    assert_includes response.body, "Time zone is not included in the list"
    assert_equal "America/New_York", @user.reload.time_zone
  end
end

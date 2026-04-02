require "test_helper"

class PushNotificationServiceTest < ActiveSupport::TestCase
  include Mocha::API

  setup do
    @user = users(:alice)
    @brief = daily_briefs(:one)
    @device = device_registrations(:alice_ios_device)
  end

  # Success scenarios
  test "daily_brief_generated sends notification when setting enabled and devices exist" do
    Setting.stubs(:push_notifications_enabled?).returns(true)

    # Create mock device
    mock_device = mock("ApplicationPushDevice")
    mock_device.stubs(:id).returns(1)

    ApplicationPushDevice.stubs(:find_by)
      .with(token: @device.device_token, platform: "apple")
      .returns(mock_device)

    notification_mock = mock("DailyBriefPushNotification")
    DailyBriefPushNotification.expects(:new)
      .with(@user, @brief)
      .returns(notification_mock)
    notification_mock.expects(:deliver_later_to).with([ mock_device ])

    PushNotificationService.daily_brief_generated(@user, @brief)
  end

  test "daily_brief_generated handles multiple devices" do
    Setting.stubs(:push_notifications_enabled?).returns(true)

    device2 = device_registrations(:alice_android_device)

    mock_apple_device = mock("AppleDevice")
    mock_google_device = mock("GoogleDevice")

    ApplicationPushDevice.stubs(:find_by)
      .with(token: @device.device_token, platform: "apple")
      .returns(mock_apple_device)
    ApplicationPushDevice.stubs(:find_by)
      .with(token: device2.device_token, platform: "google")
      .returns(mock_google_device)

    notification_mock = mock("DailyBriefPushNotification")
    DailyBriefPushNotification.expects(:new).returns(notification_mock)
    notification_mock.expects(:deliver_later_to).with([ mock_apple_device, mock_google_device ])

    PushNotificationService.daily_brief_generated(@user, @brief)
  end

  test "daily_brief_generated maps ios platform to apple" do
    Setting.stubs(:push_notifications_enabled?).returns(true)

    # Remove other devices for this user to avoid multiple lookups
    @user.device_registrations.where.not(id: @device.id).destroy_all
    @device.update!(platform: "ios")

    ApplicationPushDevice.expects(:find_by)
      .with(token: @device.device_token, platform: "apple")
      .returns(mock("Device"))

    notification_mock = mock("DailyBriefPushNotification")
    DailyBriefPushNotification.stubs(:new).returns(notification_mock)
    notification_mock.stubs(:deliver_later_to)

    PushNotificationService.daily_brief_generated(@user, @brief)
  end

  test "daily_brief_generated maps android platform to google" do
    Setting.stubs(:push_notifications_enabled?).returns(true)

    # Remove other devices for this user to avoid multiple lookups
    @user.device_registrations.where.not(id: @device.id).destroy_all
    @device.update!(platform: "android")

    ApplicationPushDevice.expects(:find_by)
      .with(token: @device.device_token, platform: "google")
      .returns(mock("Device"))

    notification_mock = mock("DailyBriefPushNotification")
    DailyBriefPushNotification.stubs(:new).returns(notification_mock)
    notification_mock.stubs(:deliver_later_to)

    PushNotificationService.daily_brief_generated(@user, @brief)
  end

  # Guard clause scenarios
  test "daily_brief_generated returns early when push notifications disabled" do
    Setting.stubs(:push_notifications_enabled?).returns(false)

    DailyBriefPushNotification.expects(:new).never

    result = PushNotificationService.daily_brief_generated(@user, @brief)
    assert_nil result
  end

  test "daily_brief_generated returns early when user has no device registrations" do
    Setting.stubs(:push_notifications_enabled?).returns(true)
    @user.device_registrations.destroy_all

    DailyBriefPushNotification.expects(:new).never

    result = PushNotificationService.daily_brief_generated(@user, @brief)
    assert_nil result
  end

  test "daily_brief_generated returns early when no matching ApplicationPushDevices found" do
    Setting.stubs(:push_notifications_enabled?).returns(true)

    ApplicationPushDevice.stubs(:find_by).returns(nil)

    DailyBriefPushNotification.expects(:new).never

    result = PushNotificationService.daily_brief_generated(@user, @brief)
    assert_nil result
  end

  # Error handling
  test "daily_brief_generated logs error when notification delivery fails" do
    Setting.stubs(:push_notifications_enabled?).returns(true)

    mock_device = mock("ApplicationPushDevice")
    ApplicationPushDevice.stubs(:find_by).returns(mock_device)

    notification_mock = mock("DailyBriefPushNotification")
    DailyBriefPushNotification.stubs(:new).returns(notification_mock)
    notification_mock.stubs(:deliver_later_to).raises(StandardError.new("Delivery failed"))

    Rails.logger.expects(:error).with(includes("Failed to send daily brief push notification"))

    # Should not raise
    assert_nothing_raised do
      PushNotificationService.daily_brief_generated(@user, @brief)
    end
  end

  test "daily_brief_generated handles device registration with unknown platform" do
    Setting.stubs(:push_notifications_enabled?).returns(true)

    @device.update!(platform: "windows_phone")

    # Should pass through unknown platform unchanged
    ApplicationPushDevice.expects(:find_by)
      .with(token: @device.device_token, platform: "windows_phone")
      .returns(mock("Device"))

    notification_mock = mock("DailyBriefPushNotification")
    DailyBriefPushNotification.stubs(:new).returns(notification_mock)
    notification_mock.stubs(:deliver_later_to)

    PushNotificationService.daily_brief_generated(@user, @brief)
  end
end

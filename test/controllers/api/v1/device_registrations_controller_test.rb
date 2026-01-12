require "test_helper"

module Api
  module V1
    class DeviceRegistrationsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = users(:alice)
        # Enable push notifications for tests
        Setting.push_notifications_enabled = true
      end

      teardown do
        # Reset to default disabled state
        Setting.push_notifications_enabled = false
      end

      test "register device token when enabled" do
        assert_difference -> { DeviceRegistration.where(user: @user).count }, 1 do
          post api_v1_device_registrations_url,
               params: { device: { device_token: "token-123", platform: "android" } },
               headers: api_headers(@user),
               as: :json
        end

        assert_response :created
        registration = DeviceRegistration.find_by(device_token: "token-123")
        assert_equal "android", registration.platform
        assert_not_nil registration.last_seen_at
      end

      test "register device token when disabled (returns success but no-op)" do
        Setting.push_notifications_enabled = false

        assert_no_difference -> { DeviceRegistration.where(user: @user).count } do
          post api_v1_device_registrations_url,
               params: { device: { device_token: "token-456", platform: "ios" } },
               headers: api_headers(@user),
               as: :json
        end

        # Still returns success for idempotency
        assert_response :created
      end

      test "register updates existing token when enabled" do
        DeviceRegistration.create!(user: @user, device_token: "token-xyz", platform: "ios")

        assert_no_difference -> { DeviceRegistration.where(user: @user).count } do
          post api_v1_device_registrations_url,
               params: { device: { device_token: "token-xyz", platform: "android" } },
               headers: api_headers(@user),
               as: :json
        end

        assert_response :created
        registration = DeviceRegistration.find_by(device_token: "token-xyz")
        assert_equal "android", registration.platform
      end

      test "destroy registration when enabled" do
        DeviceRegistration.create!(user: @user, device_token: "token-abc", platform: "android")

        assert_difference -> { DeviceRegistration.where(user: @user).count }, -1 do
          delete api_v1_device_registration_url("token-abc"),
                 headers: api_headers(@user),
                 as: :json
        end

        assert_response :no_content
      end

      test "destroy when disabled returns success (no-op)" do
        DeviceRegistration.create!(user: @user, device_token: "token-def", platform: "android")
        Setting.push_notifications_enabled = false

        assert_no_difference -> { DeviceRegistration.where(user: @user).count } do
          delete api_v1_device_registration_url("token-def"),
                 headers: api_headers(@user),
                 as: :json
        end

        assert_response :no_content
      end

      test "destroy missing token returns success" do
        delete api_v1_device_registration_url("missing"),
               headers: api_headers(@user),
               as: :json

        assert_response :no_content
      end

      test "create requires auth" do
        post api_v1_device_registrations_url,
             params: { device: { device_token: "token", platform: "android" } },
             as: :json
        assert_response :unauthorized
      end
    end
  end
end

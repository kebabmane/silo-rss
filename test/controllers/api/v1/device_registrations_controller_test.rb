require "test_helper"

module Api
  module V1
    class DeviceRegistrationsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = users(:alice)
      end

      test "register device token" do
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

      test "register updates existing token" do
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

      test "destroy registration" do
        DeviceRegistration.create!(user: @user, device_token: "token-abc", platform: "android")

        assert_difference -> { DeviceRegistration.where(user: @user).count }, -1 do
          delete api_v1_device_registration_url("token-abc"),
                 headers: api_headers(@user),
                 as: :json
        end

        assert_response :no_content
      end

      test "destroy ignores missing token" do
        delete api_v1_device_registration_url("missing"),
               headers: api_headers(@user),
               as: :json

        assert_response :not_found
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

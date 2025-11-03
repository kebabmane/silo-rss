require "test_helper"

module Api
  module V1
    class PasswordsControllerTest < ActionDispatch::IntegrationTest
      include ActiveJob::TestHelper

      setup do
        @user = users(:alice)
      end

      test "create responds with success and enqueues email when user exists" do
        assert_enqueued_emails 1 do
          post api_v1_passwords_path, params: { email: @user.email_address }, as: :json
        end

        assert_response :success
        assert_equal(
          "If your account exists, we've emailed password reset instructions.",
          response.parsed_body["message"]
        )
        @user.reload
        assert_not_nil @user.password_reset_digest
      end

      test "create responds with success even when user does not exist" do
        assert_no_enqueued_emails do
          post api_v1_passwords_path, params: { email: "missing@example.com" }, as: :json
        end

        assert_response :success
        assert_equal(
          "If your account exists, we've emailed password reset instructions.",
          response.parsed_body["message"]
        )
      end

      test "update resets password with valid token" do
        token = @user.generate_password_reset_token!

        patch api_v1_password_path(token), params: {
          password: "newpassword123",
          password_confirmation: "newpassword123"
        }, as: :json

        assert_response :success
        assert_equal "Password has been reset.", response.parsed_body["message"]

        @user.reload
        assert @user.authenticate("newpassword123")
        assert_nil @user.password_reset_digest
      end

      test "update rejects invalid token" do
        patch api_v1_password_path("invalid-token"), params: {
          password: "newpassword123",
          password_confirmation: "newpassword123"
        }, as: :json

        assert_response :unprocessable_entity
        assert_equal(
          "Password reset token is invalid or has expired.",
          response.parsed_body["error"]
        )
      end

      test "update requires password and confirmation" do
        token = @user.generate_password_reset_token!

        patch api_v1_password_path(token), params: {
          password: "newpassword123",
          password_confirmation: nil
        }, as: :json

        assert_response :unprocessable_entity
        assert_equal(
          "Password and confirmation are required.",
          response.parsed_body["error"]
        )
      end
    end
  end
end

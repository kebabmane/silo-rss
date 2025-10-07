require "test_helper"

module Admin
  class LitellmSettingsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:alice)
      sign_in_as @user
    end

    test "should get show" do
      get admin_litellm_settings_url
      assert_response :success
    end

    test "should update settings" do
      patch admin_litellm_settings_url, params: {
        litellm_setting: {
          server_url: "http://newserver:4000",
          default_model: "gpt-4",
          enabled: true
        }
      }

      assert_redirected_to admin_litellm_settings_url

      setting = LitellmSetting.instance
      assert_equal "http://newserver:4000", setting.server_url
      assert_equal "gpt-4", setting.default_model
    end

    test "should test connection" do
      LitellmSetting.instance.update!(
        enabled: true,
        server_url: "http://localhost:4000",
        default_model: "gpt-3.5-turbo"
      )

      stub_request(:get, "http://localhost:4000/models")
        .to_return(status: 200, body: { data: [] }.to_json)

      post test_connection_admin_litellm_settings_url

      assert_redirected_to admin_litellm_settings_url
      assert_equal "Connection successful!", flash[:notice]
    end

    test "should handle connection failure" do
      LitellmSetting.instance.update!(
        enabled: true,
        server_url: "http://localhost:4000",
        default_model: "gpt-3.5-turbo"
      )

      stub_request(:get, "http://localhost:4000/models")
        .to_raise(Errno::ECONNREFUSED)

      post test_connection_admin_litellm_settings_url

      assert_redirected_to admin_litellm_settings_url
      assert_match /Connection failed/, flash[:alert]
    end

    test "should fetch models" do
      LitellmSetting.instance.update!(
        enabled: true,
        server_url: "http://localhost:4000",
        default_model: "gpt-3.5-turbo"
      )

      stub_request(:get, "http://localhost:4000/models")
        .to_return(
          status: 200,
          body: { data: [{ id: "gpt-3.5-turbo" }, { id: "gpt-4" }] }.to_json
        )

      post fetch_models_admin_litellm_settings_url

      assert_response :success
      assert_match /2 models/, flash[:notice]
    end

    private

    def sign_in_as(user)
      post session_url, params: { email_address: user.email_address, password: "password" }
    end
  end
end

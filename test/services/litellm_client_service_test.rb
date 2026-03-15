require "test_helper"

class LitellmClientServiceTest < ActiveSupport::TestCase
  setup do
    @setting = LitellmSetting.instance
    @setting.update!(
      enabled: true,
      server_url: "http://localhost:4000",
      default_model: "gpt-3.5-turbo",
      api_key: "test-key"
    )
  end

  test "raises ConfigurationError when not configured" do
    @setting.update!(enabled: false)

    assert_raises(LitellmClientService::ConfigurationError) do
      LitellmClientService.new
    end
  end

  test "generate_summary makes correct API request" do
    stub_request(:post, "http://localhost:4000/chat/completions")
      .with(
        body: hash_including({
          model: "gpt-3.5-turbo"
        }),
        headers: { "Authorization" => "Bearer test-key" }
      )
      .to_return(
        status: 200,
        body: {
          choices: [
            { message: { content: "Summary result" } }
          ]
        }.to_json
      )

    client = LitellmClientService.new
    result = client.generate_summary("Test content")

    assert_equal "Summary result", result
  end

  test "list_models makes GET request" do
    stub_request(:get, "http://localhost:4000/models")
      .to_return(
        status: 200,
        body: {
          data: [
            { id: "gpt-3.5-turbo" },
            { id: "gpt-4" }
          ]
        }.to_json
      )

    client = LitellmClientService.new
    models = client.list_models

    assert_equal 2, models.count
    assert_equal "gpt-3.5-turbo", models.first["id"]
  end

  test "test_connection returns true on success" do
    stub_request(:get, "http://localhost:4000/models")
      .to_return(status: 200, body: { data: [] }.to_json)

    client = LitellmClientService.new
    assert client.test_connection
  end

  test "raises APIError on server error" do
    stub_request(:post, "http://localhost:4000/chat/completions")
      .to_return(status: 500, body: "Server error")

    client = LitellmClientService.new

    assert_raises(LitellmClientService::APIError) do
      client.generate_summary("Test")
    end
  end
end

class LitellmClientService
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class APIError < Error; end

  def initialize
    @settings = LitellmSetting.instance
    validate_configuration!
  end

  # Generate a summary from the LiteLLM server
  def generate_summary(content, options = {})
    model = options[:model] || @settings.default_model
    max_tokens = options[:max_tokens] || @settings.max_tokens
    temperature = options[:temperature] || @settings.temperature

    payload = {
      model: model,
      messages: [
        {
          role: "system",
          content: "You are a helpful assistant that creates concise, informative summaries of news articles and blog posts."
        },
        {
          role: "user",
          content: content
        }
      ],
      max_tokens: max_tokens.to_i,
      temperature: temperature.to_f
    }

    response = make_request("/chat/completions", payload)
    extract_content_from_response(response)
  rescue HTTParty::Error, SocketError, Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
    raise APIError, "Failed to communicate with LiteLLM server: #{e.message}"
  end

  # Get list of available models from the LiteLLM server
  def list_models
    response = make_request("/models", {}, :get)
    response["data"] || []
  rescue HTTParty::Error, SocketError, Timeout::Error, Errno::ECONNREFUSED, Errno::EHOSTUNREACH => e
    raise APIError, "Failed to fetch models: #{e.message}"
  end

  # Test the connection to the LiteLLM server
  def test_connection
    list_models
    true
  rescue APIError
    false
  end

  private

  def validate_configuration!
    unless @settings.configured?
      raise ConfigurationError, "LiteLLM is not properly configured"
    end
  end

  def make_request(endpoint, payload = {}, method = :post)
    url = "#{@settings.server_url.chomp('/')}#{endpoint}"

    headers = {
      "Content-Type" => "application/json"
    }

    # Add API key if present
    headers["Authorization"] = "Bearer #{@settings.api_key}" if @settings.api_key.present?

    options = {
      headers: headers,
      timeout: @settings.timeout
    }

    case method
    when :post
      options[:body] = payload.to_json
      response = HTTParty.post(url, options)
    when :get
      response = HTTParty.get(url, options)
    else
      raise ArgumentError, "Unsupported HTTP method: #{method}"
    end

    handle_response(response)
  end

  def handle_response(response)
    case response.code
    when 200..299
      JSON.parse(response.body)
    when 400..499
      raise APIError, "Client error (#{response.code}): #{response.body}"
    when 500..599
      raise APIError, "Server error (#{response.code}): #{response.body}"
    else
      raise APIError, "Unexpected response (#{response.code}): #{response.body}"
    end
  rescue JSON::ParserError => e
    raise APIError, "Invalid JSON response: #{e.message}"
  end

  def extract_content_from_response(response)
    response.dig("choices", 0, "message", "content") ||
      raise(APIError, "No content in response")
  end
end

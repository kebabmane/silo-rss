# frozen_string_literal: true

# Standardized Result object for service responses
# Provides consistent success/failure handling across all services
#
# Usage:
#   Result.success(data: articles, meta: { count: articles.size })
#   Result.failure(:not_found, "Feed not found")
#   Result.failure(:network_error, "Unable to connect", retryable: true)
#
class Result
  attr_reader :data, :error_code, :error_message, :meta

  def initialize(success:, data: nil, error_code: nil, error_message: nil, meta: {}, retryable: false)
    @success = success
    @data = data
    @error_code = error_code
    @error_message = error_message
    @meta = meta
    @retryable = retryable
  end

  # Create a successful result
  def self.success(data: nil, meta: {})
    new(success: true, data: data, meta: meta)
  end

  # Create a failed result
  def self.failure(error_code, message = nil, retryable: false, meta: {})
    new(
      success: false,
      error_code: error_code,
      error_message: message || default_message_for(error_code),
      retryable: retryable,
      meta: meta
    )
  end

  def success?
    @success
  end

  def failure?
    !@success
  end

  def retryable?
    @retryable
  end

  # Get data or raise if failure
  def unwrap!
    raise ResultError, "Cannot unwrap failure: #{error_code} - #{error_message}" if failure?

    @data
  end

  # Get data with a default fallback
  def unwrap_or(default)
    failure? ? default : @data
  end

  # Convert to hash for JSON serialization
  def to_h
    base = {
      success: @success,
      meta: @meta
    }

    if success?
      base[:data] = @data
    else
      base[:error] = {
        code: @error_code,
        message: @error_message,
        retryable: @retryable
      }
    end

    base
  end

  # Chain operations - only executes block if successful
  def and_then
    return self if failure?

    yield(@data)
  end

  # Chain error handling - only executes block if failure
  def or_else
    return self if success?

    yield(self)
  end

  class ResultError < StandardError; end

  private_class_method def self.default_message_for(code)
    case code
    when :not_found then "Resource not found"
    when :invalid_input then "Invalid input provided"
    when :network_error then "Network request failed"
    when :parse_error then "Unable to parse response"
    when :unauthorized then "Unauthorized access"
    when :conflict then "Resource conflict detected"
    else "An error occurred"
    end
  end
end

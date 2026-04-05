# frozen_string_literal: true

require "test_helper"

class ResultTest < ActiveSupport::TestCase
  test "success creates successful result with data" do
    result = Result.success(data: { articles: [ 1, 2, 3 ] })

    assert result.success?
    assert_not result.failure?
    assert_equal({ articles: [ 1, 2, 3 ] }, result.data)
  end

  test "success creates result with meta" do
    result = Result.success(data: "test", meta: { count: 1 })

    assert result.success?
    assert_equal({ count: 1 }, result.meta)
  end

  test "failure creates failed result with error code" do
    result = Result.failure(:not_found)

    assert result.failure?
    assert_not result.success?
    assert_equal :not_found, result.error_code
  end

  test "failure creates result with error message" do
    result = Result.failure(:not_found, "Resource could not be found")

    assert result.failure?
    assert_equal "Resource could not be found", result.error_message
  end

  test "failure creates result with retryable flag" do
    result = Result.failure(:network_error, "Connection failed", retryable: true)

    assert result.retryable?
    assert result.failure?
  end

  test "non-retryable failure returns false for retryable" do
    result = Result.failure(:not_found, "Not found")

    assert_not result.retryable?
  end

  test "unwrap returns data for success" do
    result = Result.success(data: { test: "data" })

    assert_equal({ test: "data" }, result.unwrap!)
  end

  test "unwrap raises for failure" do
    result = Result.failure(:error, "Something went wrong")

    assert_raises(Result::ResultError) do
      result.unwrap!
    end
  end

  test "unwrap_or returns data for success" do
    result = Result.success(data: "actual data")

    assert_equal "actual data", result.unwrap_or("default")
  end

  test "unwrap_or returns default for failure" do
    result = Result.failure(:not_found)

    assert_equal "default", result.unwrap_or("default")
  end

  test "and_then yields for success" do
    result = Result.success(data: 5)
    new_result = result.and_then { |n| Result.success(data: n * 2) }

    assert_equal 10, new_result.data
  end

  test "and_then returns self for failure" do
    result = Result.failure(:error)
    called = false
    new_result = result.and_then { |data| called = true; Result.success(data: data) }

    assert_not called
    assert_equal result, new_result
  end

  test "or_else yields for failure" do
    result = Result.failure(:not_found, "Not found")
    called = false
    result.or_else { |r| called = true; r }

    assert called
  end

  test "or_else returns self for success" do
    result = Result.success(data: "test")
    called = false
    result.or_else { |r| called = true; r }

    assert_not called
  end

  test "to_h returns hash for success" do
    result = Result.success(data: { test: "value" }, meta: { count: 1 })
    hash = result.to_h

    assert_equal({
      success: true,
      data: { test: "value" },
      meta: { count: 1 }
    }, hash)
  end

  test "to_h returns hash for failure" do
    result = Result.failure(:network_error, "Failed", retryable: true)
    hash = result.to_h

    assert_equal({
      success: false,
      meta: {},
      error: {
        code: :network_error,
        message: "Failed",
        retryable: true
      }
    }, hash)
  end

  test "default messages are provided for common error codes" do
    assert_match /not found/i, Result.failure(:not_found).error_message
    assert_match /invalid/i, Result.failure(:invalid_input).error_message
    assert_match /network/i, Result.failure(:network_error).error_message
    assert_match /parse/i, Result.failure(:parse_error).error_message
    assert_match /unauthorized/i, Result.failure(:unauthorized).error_message
    assert_match /conflict/i, Result.failure(:conflict).error_message
  end

  test "custom message overrides default" do
    result = Result.failure(:not_found, "Custom not found message")

    assert_equal "Custom not found message", result.error_message
  end
end

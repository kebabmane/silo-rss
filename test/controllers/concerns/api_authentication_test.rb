require "test_helper"

class ApiAuthenticationTest < ActionDispatch::IntegrationTest
  # Dummy controller for testing the ApiAuthentication concern
  class TestController < ApplicationController
    include ApiAuthentication

    def index
      render json: { message: "Index action", user: current_user.email_address }
    end

    def show
      render json: { user_id: current_user.id, email: current_user.email_address }
    end
  end

  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      get "/api/test/index" => "api_authentication_test/test#index"
      get "/api/test/show" => "api_authentication_test/test#show"
    end

    @original_routes = Rails.application.routes
    Rails.application.routes = @routes

    @alice = users(:alice)
    @bob = users(:bob)
    @charlie = users(:charlie)
  end

  teardown do
    Rails.application.routes = @original_routes
  end

  # Test: authenticate_api_user with valid token
  test "authenticate_api_user allows access with valid Bearer token" do
    get "/api/test/index", headers: { "Authorization" => "Bearer #{@alice.api_token}" }
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "Index action", json_response["message"]
    assert_equal @alice.email_address, json_response["user"]
  end

  test "authenticate_api_user sets @current_user with valid token" do
    get "/api/test/show", headers: { "Authorization" => "Bearer #{@alice.api_token}" }
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal @alice.id, json_response["user_id"]
    assert_equal @alice.email_address, json_response["email"]
  end

  test "authenticate_api_user works with different users" do
    # Test with Alice
    get "/api/test/index", headers: { "Authorization" => "Bearer #{@alice.api_token}" }
    assert_response :success
    assert_equal @alice.email_address, JSON.parse(response.body)["user"]

    # Test with Bob
    get "/api/test/index", headers: { "Authorization" => "Bearer #{@bob.api_token}" }
    assert_response :success
    assert_equal @bob.email_address, JSON.parse(response.body)["user"]

    # Test with Charlie
    get "/api/test/index", headers: { "Authorization" => "Bearer #{@charlie.api_token}" }
    assert_response :success
    assert_equal @charlie.email_address, JSON.parse(response.body)["user"]
  end

  # Test: authenticate_api_user with invalid/missing token
  test "authenticate_api_user returns unauthorized when no Authorization header" do
    get "/api/test/index"
    assert_response :unauthorized

    json_response = JSON.parse(response.body)
    assert_equal "Unauthorized", json_response["error"]
  end

  test "authenticate_api_user returns unauthorized with empty Authorization header" do
    get "/api/test/index", headers: { "Authorization" => "" }
    assert_response :unauthorized

    json_response = JSON.parse(response.body)
    assert_equal "Unauthorized", json_response["error"]
  end

  test "authenticate_api_user returns unauthorized with invalid token" do
    get "/api/test/index", headers: { "Authorization" => "Bearer invalid_token_12345" }
    assert_response :unauthorized

    json_response = JSON.parse(response.body)
    assert_equal "Unauthorized", json_response["error"]
  end

  test "authenticate_api_user returns unauthorized with non-existent token" do
    get "/api/test/index", headers: { "Authorization" => "Bearer aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" }
    assert_response :unauthorized

    json_response = JSON.parse(response.body)
    assert_equal "Unauthorized", json_response["error"]
  end

  test "authenticate_api_user returns unauthorized when token is nil" do
    get "/api/test/index", headers: { "Authorization" => "Bearer " }
    assert_response :unauthorized

    json_response = JSON.parse(response.body)
    assert_equal "Unauthorized", json_response["error"]
  end

  # Test: Bearer token parsing
  test "authenticate_api_user correctly parses Bearer token with Bearer prefix" do
    get "/api/test/index", headers: { "Authorization" => "Bearer #{@alice.api_token}" }
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal @alice.email_address, json_response["user"]
  end

  test "authenticate_api_user handles token without Bearer prefix" do
    # The implementation uses gsub('Bearer ', '') so token without prefix should work
    get "/api/test/index", headers: { "Authorization" => @alice.api_token }
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal @alice.email_address, json_response["user"]
  end

  test "authenticate_api_user handles multiple Bearer words in header" do
    # Edge case: what if someone sends "Bearer Bearer token"?
    # The gsub will only remove the first "Bearer " occurrence
    token_with_bearer = "Bearer #{@alice.api_token}"
    get "/api/test/index", headers: { "Authorization" => "Bearer #{token_with_bearer}" }
    assert_response :unauthorized
  end

  test "authenticate_api_user is case sensitive for Bearer keyword" do
    # Test lowercase bearer
    get "/api/test/index", headers: { "Authorization" => "bearer #{@alice.api_token}" }
    assert_response :unauthorized

    # Test uppercase BEARER
    get "/api/test/index", headers: { "Authorization" => "BEARER #{@alice.api_token}" }
    assert_response :unauthorized
  end

  # Test: current_user method
  test "current_user returns authenticated user" do
    controller = TestController.new
    controller.request = ActionDispatch::TestRequest.create({
      "HTTP_AUTHORIZATION" => "Bearer #{@alice.api_token}"
    })
    controller.response = ActionDispatch::TestResponse.new

    controller.send(:authenticate_api_user)
    assert_equal @alice.id, controller.send(:current_user).id
  end

  test "current_user returns nil when not authenticated" do
    controller = TestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new

    # Before authentication, current_user should be nil
    assert_nil controller.send(:current_user)
  end

  # Edge cases and security tests
  test "authenticate_api_user handles Authorization header with extra whitespace" do
    get "/api/test/index", headers: { "Authorization" => "Bearer  #{@alice.api_token}" }
    # This will fail because of the extra space, which is correct behavior
    assert_response :unauthorized
  end

  test "authenticate_api_user handles token with leading/trailing whitespace" do
    token_with_whitespace = " #{@alice.api_token} "
    get "/api/test/index", headers: { "Authorization" => "Bearer #{token_with_whitespace}" }
    # Should fail because token doesn't match exactly
    assert_response :unauthorized
  end

  test "authenticate_api_user rejects SQL injection attempts in token" do
    malicious_token = "' OR '1'='1"
    get "/api/test/index", headers: { "Authorization" => "Bearer #{malicious_token}" }
    assert_response :unauthorized

    json_response = JSON.parse(response.body)
    assert_equal "Unauthorized", json_response["error"]
  end

  test "authenticate_api_user handles very long tokens" do
    long_token = "a" * 10000
    get "/api/test/index", headers: { "Authorization" => "Bearer #{long_token}" }
    assert_response :unauthorized
  end

  test "authenticate_api_user handles special characters in token" do
    special_token = "token!@#$%^&*()_+-=[]{}|;:',.<>?/~`"
    get "/api/test/index", headers: { "Authorization" => "Bearer #{special_token}" }
    assert_response :unauthorized
  end

  test "authenticate_api_user handles empty Bearer prefix" do
    get "/api/test/index", headers: { "Authorization" => "Bearer" }
    assert_response :unauthorized
  end

  test "authenticate_api_user handles only whitespace in Authorization header" do
    get "/api/test/index", headers: { "Authorization" => "   " }
    assert_response :unauthorized
  end

  test "authenticate_api_user is called before every action" do
    # Verify that attempting to access any action without auth fails
    get "/api/test/index"
    assert_response :unauthorized

    get "/api/test/show"
    assert_response :unauthorized
  end

  # Test: Multiple requests with same token
  test "same token can be used for multiple requests" do
    # First request
    get "/api/test/index", headers: { "Authorization" => "Bearer #{@alice.api_token}" }
    assert_response :success
    assert_equal @alice.email_address, JSON.parse(response.body)["user"]

    # Second request with same token
    get "/api/test/show", headers: { "Authorization" => "Bearer #{@alice.api_token}" }
    assert_response :success
    assert_equal @alice.id, JSON.parse(response.body)["user_id"]
  end

  # Test: Token regeneration scenario
  test "old token is invalid after regeneration" do
    old_token = @alice.api_token

    # Request with old token works
    get "/api/test/index", headers: { "Authorization" => "Bearer #{old_token}" }
    assert_response :success

    # Regenerate token
    @alice.regenerate_api_token!

    # Request with old token should fail
    get "/api/test/index", headers: { "Authorization" => "Bearer #{old_token}" }
    assert_response :unauthorized

    # Request with new token should work
    get "/api/test/index", headers: { "Authorization" => "Bearer #{@alice.api_token}" }
    assert_response :success
  end

  # Test: Response format
  test "unauthorized response returns JSON with error key" do
    get "/api/test/index"
    assert_response :unauthorized
    assert_equal "application/json; charset=utf-8", response.content_type

    json_response = JSON.parse(response.body)
    assert json_response.key?("error")
    assert_equal "Unauthorized", json_response["error"]
  end

  test "unauthorized response has correct status code" do
    get "/api/test/index"
    assert_response 401
  end

  # Test: Different authorization schemes
  test "authenticate_api_user rejects Basic auth" do
    basic_auth = Base64.strict_encode64("#{@alice.email_address}:password")
    get "/api/test/index", headers: { "Authorization" => "Basic #{basic_auth}" }
    assert_response :unauthorized
  end

  test "authenticate_api_user rejects Digest auth" do
    get "/api/test/index", headers: { "Authorization" => "Digest username=\"alice\"" }
    assert_response :unauthorized
  end

  # Test: Header case sensitivity
  test "authenticate_api_user uses Authorization header case-insensitively" do
    # Rails normalizes header names, so this should work
    get "/api/test/index", headers: { "authorization" => "Bearer #{@alice.api_token}" }
    assert_response :success
  end

  # Test: Concurrent users
  test "different users cannot use each other's tokens" do
    # Alice's token should not work for Bob's account
    get "/api/test/index", headers: { "Authorization" => "Bearer #{@alice.api_token}" }
    assert_response :success
    assert_equal @alice.email_address, JSON.parse(response.body)["user"]

    # Verify we get Alice, not Bob
    assert_not_equal @bob.email_address, JSON.parse(response.body)["user"]
  end

  # Test: current_user persistence across multiple method calls
  test "current_user remains consistent within single request" do
    controller = TestController.new
    controller.request = ActionDispatch::TestRequest.create({
      "HTTP_AUTHORIZATION" => "Bearer #{@alice.api_token}"
    })
    controller.response = ActionDispatch::TestResponse.new

    controller.send(:authenticate_api_user)

    # Call current_user multiple times
    user1 = controller.send(:current_user)
    user2 = controller.send(:current_user)
    user3 = controller.send(:current_user)

    assert_equal user1.id, user2.id
    assert_equal user2.id, user3.id
    assert_equal @alice.id, user1.id
  end
end

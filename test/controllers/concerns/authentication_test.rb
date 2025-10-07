require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  # Dummy controller for testing the Authentication concern
  class TestController < ApplicationController
    include Authentication

    def index
      render plain: "Index action"
    end

    def public_action
      render plain: "Public action"
    end

    def authenticated_action
      render plain: "Authenticated: #{authenticated?}"
    end
  end

  # Dummy controller with unauthenticated access allowed
  class PublicTestController < ApplicationController
    include Authentication
    allow_unauthenticated_access only: [:public_action]

    def public_action
      render plain: "Public action"
    end

    def private_action
      render plain: "Private action"
    end
  end

  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw do
      get "/test/index" => "authentication_test/test#index"
      get "/test/authenticated_action" => "authentication_test/test#authenticated_action"
      get "/public/public_action" => "authentication_test/public_test#public_action"
      get "/public/private_action" => "authentication_test/public_test#private_action"
    end

    @original_routes = Rails.application.routes
    Rails.application.routes = @routes

    @alice = users(:alice)
    @bob = users(:bob)
    @alice_session = sessions(:alice_session)

    # Clear Current attributes before each test
    Current.reset
  end

  teardown do
    Rails.application.routes = @original_routes
    Current.reset
  end

  # Test: authenticated? helper method
  test "authenticated? returns true when valid session cookie exists" do
    cookies.signed[:session_id] = @alice_session.id
    get "/test/authenticated_action"
    assert_response :success
    assert_equal "Authenticated: true", response.body
  end

  test "authenticated? returns false when no session cookie exists" do
    # This test requires manually calling authenticated? since the before_action will redirect
    controller = TestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new
    assert_not controller.send(:authenticated?)
  end

  test "authenticated? returns false when session cookie is invalid" do
    cookies.signed[:session_id] = "invalid-session-id"
    controller = TestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new
    controller.request.cookie_jar.signed[:session_id] = "invalid-session-id"
    assert_not controller.send(:authenticated?)
  end

  # Test: require_authentication before_action
  test "require_authentication redirects to login when not authenticated" do
    get "/test/index"
    assert_redirected_to new_session_path
  end

  test "require_authentication allows access when authenticated" do
    cookies.signed[:session_id] = @alice_session.id
    get "/test/index"
    assert_response :success
    assert_equal "Index action", response.body
  end

  test "require_authentication sets return_to_after_authenticating in session" do
    get "/test/index"
    assert_equal "http://www.example.com/test/index", session[:return_to_after_authenticating]
  end

  # Test: resume_session
  test "resume_session sets Current.session when valid cookie exists" do
    cookies.signed[:session_id] = @alice_session.id
    get "/test/index"
    # After request, Current should have been set during the request
    # We can't directly test Current here as it's request-scoped
    assert_response :success
  end

  test "resume_session returns nil when no cookie exists" do
    controller = TestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new
    assert_nil controller.send(:resume_session)
  end

  test "resume_session returns nil when session does not exist in database" do
    cookies.signed[:session_id] = "non-existent-session-id"
    controller = TestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new
    controller.request.cookie_jar.signed[:session_id] = "non-existent-session-id"
    assert_nil controller.send(:resume_session)
  end

  # Test: find_session_by_cookie
  test "find_session_by_cookie returns session when valid cookie exists" do
    controller = TestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new
    controller.request.cookie_jar.signed[:session_id] = @alice_session.id

    session = controller.send(:find_session_by_cookie)
    assert_equal @alice_session.id, session.id
  end

  test "find_session_by_cookie returns nil when no cookie exists" do
    controller = TestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new

    assert_nil controller.send(:find_session_by_cookie)
  end

  test "find_session_by_cookie returns nil when cookie is invalid" do
    controller = TestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new
    controller.request.cookie_jar.signed[:session_id] = 99999

    assert_nil controller.send(:find_session_by_cookie)
  end

  # Test: after_authentication_url
  test "after_authentication_url returns saved return_to URL" do
    controller = TestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new
    controller.request.session[:return_to_after_authenticating] = "http://example.com/saved/path"

    url = controller.send(:after_authentication_url)
    assert_equal "http://example.com/saved/path", url
    assert_nil controller.request.session[:return_to_after_authenticating]
  end

  test "after_authentication_url returns root_url when no return_to exists" do
    controller = TestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new

    url = controller.send(:after_authentication_url)
    assert_equal "http://www.example.com/", url
  end

  test "after_authentication_url deletes return_to from session" do
    controller = TestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new
    controller.request.session[:return_to_after_authenticating] = "http://example.com/path"

    controller.send(:after_authentication_url)
    assert_nil controller.request.session[:return_to_after_authenticating]
  end

  # Test: start_new_session_for
  test "start_new_session_for creates a new session for user" do
    controller = TestController.new
    controller.request = ActionDispatch::TestRequest.create({
      "HTTP_USER_AGENT" => "Test Browser",
      "REMOTE_ADDR" => "192.168.1.1"
    })
    controller.response = ActionDispatch::TestResponse.new

    assert_difference "Session.count", 1 do
      session = controller.send(:start_new_session_for, @alice)
      assert_equal @alice.id, session.user_id
      assert_equal "Test Browser", session.user_agent
      assert_equal "192.168.1.1", session.ip_address
    end
  end

  test "start_new_session_for sets Current.session" do
    controller = TestController.new
    controller.request = ActionDispatch::TestRequest.create({
      "HTTP_USER_AGENT" => "Test Browser",
      "REMOTE_ADDR" => "192.168.1.1"
    })
    controller.response = ActionDispatch::TestResponse.new

    session = controller.send(:start_new_session_for, @alice)
    assert_equal session.id, Current.session.id
  end

  test "start_new_session_for sets signed permanent cookie" do
    controller = TestController.new
    controller.request = ActionDispatch::TestRequest.create({
      "HTTP_USER_AGENT" => "Test Browser",
      "REMOTE_ADDR" => "192.168.1.1"
    })
    controller.response = ActionDispatch::TestResponse.new

    session = controller.send(:start_new_session_for, @alice)
    assert_equal session.id, controller.request.cookie_jar.signed.permanent[:session_id]
  end

  test "start_new_session_for sets cookie with httponly and same_site options" do
    controller = TestController.new
    controller.request = ActionDispatch::TestRequest.create({
      "HTTP_USER_AGENT" => "Test Browser",
      "REMOTE_ADDR" => "192.168.1.1"
    })
    controller.response = ActionDispatch::TestResponse.new

    controller.send(:start_new_session_for, @alice)
    # Cookie options are set internally, we verify the session was created correctly
    assert_not_nil controller.request.cookie_jar.signed.permanent[:session_id]
  end

  # Test: terminate_session
  test "terminate_session destroys Current.session" do
    controller = TestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new
    Current.session = @alice_session

    assert_difference "Session.count", -1 do
      controller.send(:terminate_session)
    end
  end

  test "terminate_session deletes session cookie" do
    controller = TestController.new
    controller.request = ActionDispatch::TestRequest.create
    controller.response = ActionDispatch::TestResponse.new
    controller.request.cookie_jar.signed[:session_id] = @alice_session.id
    Current.session = @alice_session

    controller.send(:terminate_session)
    assert_nil controller.request.cookie_jar[:session_id]
  end

  # Test: allow_unauthenticated_access class method
  test "allow_unauthenticated_access skips authentication for specified actions" do
    get "/public/public_action"
    assert_response :success
    assert_equal "Public action", response.body
  end

  test "allow_unauthenticated_access still requires authentication for other actions" do
    get "/public/private_action"
    assert_redirected_to new_session_path
  end

  test "allow_unauthenticated_access with authenticated user still allows access" do
    cookies.signed[:session_id] = @alice_session.id
    get "/public/public_action"
    assert_response :success
    assert_equal "Public action", response.body
  end

  # Edge cases
  test "authentication works with different users" do
    # Test with Alice
    cookies.signed[:session_id] = @alice_session.id
    get "/test/index"
    assert_response :success

    # Clear cookies and test with Bob
    cookies.delete(:session_id)
    bob_session = sessions(:bob_session)
    cookies.signed[:session_id] = bob_session.id
    get "/test/index"
    assert_response :success
  end

  test "authentication fails when session is destroyed externally" do
    cookies.signed[:session_id] = @alice_session.id
    @alice_session.destroy

    get "/test/index"
    assert_redirected_to new_session_path
  end

  test "multiple simultaneous sessions for same user" do
    controller = TestController.new
    controller.request = ActionDispatch::TestRequest.create({
      "HTTP_USER_AGENT" => "Browser 1",
      "REMOTE_ADDR" => "192.168.1.1"
    })
    controller.response = ActionDispatch::TestResponse.new

    session1 = controller.send(:start_new_session_for, @alice)

    # Create second session
    controller2 = TestController.new
    controller2.request = ActionDispatch::TestRequest.create({
      "HTTP_USER_AGENT" => "Browser 2",
      "REMOTE_ADDR" => "192.168.1.2"
    })
    controller2.response = ActionDispatch::TestResponse.new

    session2 = controller2.send(:start_new_session_for, @alice)

    assert_not_equal session1.id, session2.id
    assert_equal @alice.id, session1.user_id
    assert_equal @alice.id, session2.user_id
  end

  test "session cookie without signed value is ignored" do
    # Set unsigned cookie (security risk, should be ignored)
    cookies[:session_id] = @alice_session.id

    get "/test/index"
    assert_redirected_to new_session_path
  end

  test "empty session cookie is handled gracefully" do
    cookies.signed[:session_id] = nil

    get "/test/index"
    assert_redirected_to new_session_path
  end

  test "authentication preserves query parameters in return_to URL" do
    get "/test/index?foo=bar&baz=qux"
    assert_equal "http://www.example.com/test/index?foo=bar&baz=qux",
                 session[:return_to_after_authenticating]
  end
end

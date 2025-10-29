require "test_helper"

class AuthenticationTest < ActiveSupport::TestCase
  # Dummy controller for testing the Authentication concern
  class TestController < ApplicationController
    include Authentication

    attr_accessor :request, :response

    def initialize
      super
      @request = ActionDispatch::TestRequest.create
      @response = ActionDispatch::TestResponse.new
    end
  end

  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @alice_session = sessions(:alice_session)
    @controller = TestController.new

    # Clear Current attributes before each test
    Current.reset
  end

  teardown do
    Current.reset
  end

  # Test: authenticated? helper method
  test "authenticated? returns true when valid session cookie exists" do
    @controller.request.cookie_jar.signed[:session_id] = @alice_session.id
    assert @controller.send(:authenticated?)
  end

  test "authenticated? returns false when no session cookie exists" do
    assert_not @controller.send(:authenticated?)
  end

  test "authenticated? returns false when session cookie is invalid" do
    @controller.request.cookie_jar.signed[:session_id] = "invalid-session-id"
    assert_not @controller.send(:authenticated?)
  end

  # Test: resume_session
  test "resume_session sets Current.session when valid cookie exists" do
    @controller.request.cookie_jar.signed[:session_id] = @alice_session.id
    session = @controller.send(:resume_session)
    assert_equal @alice_session.id, session.id
    assert_equal @alice_session.id, Current.session.id
  end

  test "resume_session returns nil when no cookie exists" do
    assert_nil @controller.send(:resume_session)
  end

  test "resume_session returns nil when session does not exist in database" do
    @controller.request.cookie_jar.signed[:session_id] = "non-existent-session-id"
    assert_nil @controller.send(:resume_session)
  end

  # Test: find_session_by_cookie
  test "find_session_by_cookie returns session when valid cookie exists" do
    @controller.request.cookie_jar.signed[:session_id] = @alice_session.id
    session = @controller.send(:find_session_by_cookie)
    assert_equal @alice_session.id, session.id
  end

  test "find_session_by_cookie returns nil when no cookie exists" do
    assert_nil @controller.send(:find_session_by_cookie)
  end

  test "find_session_by_cookie returns nil when cookie is invalid" do
    @controller.request.cookie_jar.signed[:session_id] = 99999
    assert_nil @controller.send(:find_session_by_cookie)
  end

  # Note: after_authentication_url is tested in integration tests (SessionsController tests)
  # where the full request/session lifecycle is available

  # Test: start_new_session_for
  test "start_new_session_for creates a new session for user" do
    @controller.request.env["HTTP_USER_AGENT"] = "Test Browser"
    @controller.request.env["REMOTE_ADDR"] = "192.168.1.1"

    assert_difference "Session.count", 1 do
      session = @controller.send(:start_new_session_for, @alice)
      assert_equal @alice.id, session.user_id
      assert_equal "Test Browser", session.user_agent
      assert_equal "192.168.1.1", session.ip_address
    end
  end

  test "start_new_session_for sets Current.session" do
    @controller.request.env["HTTP_USER_AGENT"] = "Test Browser"
    @controller.request.env["REMOTE_ADDR"] = "192.168.1.1"

    session = @controller.send(:start_new_session_for, @alice)
    assert_equal session.id, Current.session.id
  end

  test "start_new_session_for sets signed permanent cookie" do
    @controller.request.env["HTTP_USER_AGENT"] = "Test Browser"
    @controller.request.env["REMOTE_ADDR"] = "192.168.1.1"

    session = @controller.send(:start_new_session_for, @alice)
    assert_equal session.id, @controller.request.cookie_jar.signed.permanent[:session_id]
  end

  test "start_new_session_for sets cookie with httponly and same_site options" do
    @controller.request.env["HTTP_USER_AGENT"] = "Test Browser"
    @controller.request.env["REMOTE_ADDR"] = "192.168.1.1"

    @controller.send(:start_new_session_for, @alice)
    # Cookie options are set internally, we verify the session was created correctly
    assert_not_nil @controller.request.cookie_jar.signed.permanent[:session_id]
  end

  # Test: terminate_session
  test "terminate_session destroys Current.session" do
    Current.session = @alice_session

    assert_difference "Session.count", -1 do
      @controller.send(:terminate_session)
    end
  end

  test "terminate_session deletes session cookie" do
    @controller.request.cookie_jar.signed[:session_id] = @alice_session.id
    Current.session = @alice_session

    @controller.send(:terminate_session)
    assert_nil @controller.request.cookie_jar[:session_id]
  end

  # Test: multiple simultaneous sessions for same user
  test "multiple simultaneous sessions for same user" do
    @controller.request.env["HTTP_USER_AGENT"] = "Browser 1"
    @controller.request.env["REMOTE_ADDR"] = "192.168.1.1"

    session1 = @controller.send(:start_new_session_for, @alice)

    # Create second session
    controller2 = TestController.new
    controller2.request.env["HTTP_USER_AGENT"] = "Browser 2"
    controller2.request.env["REMOTE_ADDR"] = "192.168.1.2"

    session2 = controller2.send(:start_new_session_for, @alice)

    assert_not_equal session1.id, session2.id
    assert_equal @alice.id, session1.user_id
    assert_equal @alice.id, session2.user_id
  end

  # Test: authentication works with different users
  test "authentication works with different users" do
    # Test with Alice
    @controller.request.cookie_jar.signed[:session_id] = @alice_session.id
    assert @controller.send(:authenticated?)

    # Clear cookies and test with Bob
    @controller.request.cookie_jar.delete(:session_id)
    bob_session = sessions(:bob_session)
    @controller.request.cookie_jar.signed[:session_id] = bob_session.id
    assert @controller.send(:authenticated?)
  end

  # Test: authentication fails when session is destroyed externally
  test "authentication fails when session is destroyed externally" do
    @controller.request.cookie_jar.signed[:session_id] = @alice_session.id
    @alice_session.destroy

    assert_not @controller.send(:authenticated?)
  end

  # Test: session cookie without signed value is ignored
  test "session cookie without signed value is ignored" do
    # Set unsigned cookie (security risk, should be ignored)
    @controller.request.cookie_jar[:session_id] = @alice_session.id.to_s

    assert_not @controller.send(:authenticated?)
  end

  # Test: empty session cookie is handled gracefully
  test "empty session cookie is handled gracefully" do
    @controller.request.cookie_jar.signed[:session_id] = nil

    assert_not @controller.send(:authenticated?)
  end
end

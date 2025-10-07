require "test_helper"

class CurrentTest < ActiveSupport::TestCase
  setup do
    # Reset Current attributes before each test
    Current.reset
  end

  teardown do
    # Clean up Current attributes after each test
    Current.reset
  end

  # Basic functionality tests
  test "Current is an ActiveSupport::CurrentAttributes" do
    assert_kind_of Class, Current
    assert_equal ActiveSupport::CurrentAttributes, Current.superclass
  end

  test "session attribute can be set" do
    session = sessions(:alice_session)
    Current.session = session
    assert_equal session, Current.session
  end

  test "session attribute defaults to nil" do
    assert_nil Current.session
  end

  test "session can be set to nil" do
    session = sessions(:alice_session)
    Current.session = session
    assert_equal session, Current.session

    Current.session = nil
    assert_nil Current.session
  end

  # Delegation tests
  test "user delegates to session" do
    session = sessions(:alice_session)
    Current.session = session
    assert_equal users(:alice), Current.user
  end

  test "user returns nil when session is nil" do
    Current.session = nil
    assert_nil Current.user
  end

  test "user allows nil session due to allow_nil option" do
    # This should not raise an error even though session is nil
    assert_nothing_raised do
      Current.user
    end
  end

  test "user changes when session changes" do
    alice_session = sessions(:alice_session)
    bob_session = sessions(:bob_session)

    Current.session = alice_session
    assert_equal users(:alice), Current.user

    Current.session = bob_session
    assert_equal users(:bob), Current.user
  end

  # Reset tests
  test "reset clears session" do
    session = sessions(:alice_session)
    Current.session = session
    assert_equal session, Current.session

    Current.reset
    assert_nil Current.session
  end

  test "reset clears user through session" do
    session = sessions(:alice_session)
    Current.session = session
    assert_equal users(:alice), Current.user

    Current.reset
    assert_nil Current.user
  end

  # Thread safety tests
  test "Current attributes are thread-local" do
    alice_session = sessions(:alice_session)
    bob_session = sessions(:bob_session)

    # Set in main thread
    Current.session = alice_session
    assert_equal alice_session, Current.session

    # Set different value in another thread
    thread = Thread.new do
      Current.session = bob_session
      assert_equal bob_session, Current.session
      assert_equal users(:bob), Current.user
    end
    thread.join

    # Main thread should still have alice's session
    assert_equal alice_session, Current.session
    assert_equal users(:alice), Current.user
  end

  # Integration tests
  test "can access user attributes through Current" do
    session = sessions(:alice_session)
    Current.session = session

    assert_not_nil Current.user
    assert_equal users(:alice).email_address, Current.user.email_address
  end

  test "can check if user is present" do
    assert_nil Current.user

    Current.session = sessions(:alice_session)
    assert_not_nil Current.user
  end

  test "works with multiple session switches" do
    alice_session = sessions(:alice_session)
    bob_session = sessions(:bob_session)

    Current.session = alice_session
    assert_equal users(:alice), Current.user

    Current.session = bob_session
    assert_equal users(:bob), Current.user

    Current.session = alice_session
    assert_equal users(:alice), Current.user

    Current.reset
    assert_nil Current.user
  end

  # Edge cases
  test "user returns nil for session without user" do
    # Create a session instance but don't save it (edge case)
    session = Session.new
    Current.session = session

    # Should return nil because session.user is nil
    assert_nil Current.user
  end

  test "responds to session attribute methods" do
    assert_respond_to Current, :session
    assert_respond_to Current, :session=
  end

  test "responds to user method" do
    assert_respond_to Current, :user
  end

  test "multiple resets are safe" do
    Current.session = sessions(:alice_session)
    assert_not_nil Current.session

    Current.reset
    assert_nil Current.session

    Current.reset
    assert_nil Current.session

    Current.reset
    assert_nil Current.session
  end

  test "setting session to same value twice works" do
    session = sessions(:alice_session)

    Current.session = session
    assert_equal session, Current.session

    Current.session = session
    assert_equal session, Current.session
  end

  test "can alternate between different sessions" do
    alice_session = sessions(:alice_session)
    bob_session = sessions(:bob_session)

    10.times do
      Current.session = alice_session
      assert_equal users(:alice), Current.user

      Current.session = bob_session
      assert_equal users(:bob), Current.user
    end
  end
end

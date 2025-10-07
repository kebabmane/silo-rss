require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "valid session" do
    session = Session.new(
      user: users(:alice),
      ip_address: "192.168.1.1",
      user_agent: "Mozilla/5.0"
    )
    assert session.valid?
  end

  # Association tests
  test "belongs to user" do
    session = sessions(:alice_session)
    assert_respond_to session, :user
    assert_kind_of User, session.user
    assert_equal users(:alice), session.user
  end

  test "requires user" do
    session = Session.new(
      ip_address: "192.168.1.1",
      user_agent: "Mozilla/5.0"
    )
    assert_not session.valid?
    assert_includes session.errors[:user], "must exist"
  end

  # Attribute tests
  test "allows ip_address to be set" do
    session = Session.create!(
      user: users(:alice),
      ip_address: "203.0.113.42",
      user_agent: "Mozilla/5.0"
    )
    assert_equal "203.0.113.42", session.ip_address
  end

  test "allows user_agent to be set" do
    session = Session.create!(
      user: users(:alice),
      ip_address: "192.168.1.1",
      user_agent: "Chrome/118.0"
    )
    assert_equal "Chrome/118.0", session.user_agent
  end

  test "allows ip_address to be nil" do
    session = Session.new(
      user: users(:alice),
      ip_address: nil,
      user_agent: "Mozilla/5.0"
    )
    assert session.valid?
  end

  test "allows user_agent to be nil" do
    session = Session.new(
      user: users(:alice),
      ip_address: "192.168.1.1",
      user_agent: nil
    )
    assert session.valid?
  end

  # Multiple sessions for same user
  test "user can have multiple sessions" do
    user = users(:alice)
    session1 = sessions(:alice_session)
    session2 = Session.create!(
      user: user,
      ip_address: "10.0.0.1",
      user_agent: "Safari/17.0"
    )
    assert session2.valid?
    assert_equal user, session1.user
    assert_equal user, session2.user
  end

  test "different users can have separate sessions" do
    alice_session = sessions(:alice_session)
    bob_session = sessions(:bob_session)

    assert_equal users(:alice), alice_session.user
    assert_equal users(:bob), bob_session.user
    assert_not_equal alice_session.user, bob_session.user
  end

  # Edge cases
  test "session can be created with minimal attributes" do
    session = Session.create!(
      user: users(:charlie)
    )
    assert session.valid?
    assert_equal users(:charlie), session.user
  end

  test "ip_address can contain IPv4 address" do
    session = Session.create!(
      user: users(:alice),
      ip_address: "192.168.0.1"
    )
    assert_equal "192.168.0.1", session.ip_address
  end

  test "ip_address can contain IPv6 address" do
    session = Session.create!(
      user: users(:alice),
      ip_address: "2001:0db8:85a3:0000:0000:8a2e:0370:7334"
    )
    assert_equal "2001:0db8:85a3:0000:0000:8a2e:0370:7334", session.ip_address
  end

  test "user_agent can contain long string" do
    long_user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36"
    session = Session.create!(
      user: users(:alice),
      user_agent: long_user_agent
    )
    assert_equal long_user_agent, session.user_agent
  end

  test "user_agent can contain mobile user agent" do
    mobile_user_agent = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15"
    session = Session.create!(
      user: users(:alice),
      user_agent: mobile_user_agent
    )
    assert_equal mobile_user_agent, session.user_agent
  end

  test "can update ip_address" do
    session = sessions(:alice_session)
    original_ip = session.ip_address
    session.update!(ip_address: "10.0.0.100")
    assert_equal "10.0.0.100", session.reload.ip_address
    assert_not_equal original_ip, session.ip_address
  end

  test "can update user_agent" do
    session = sessions(:alice_session)
    original_user_agent = session.user_agent
    session.update!(user_agent: "Updated Browser/1.0")
    assert_equal "Updated Browser/1.0", session.reload.user_agent
    assert_not_equal original_user_agent, session.user_agent
  end

  test "session has timestamps" do
    session = Session.create!(
      user: users(:charlie),
      ip_address: "192.168.1.1"
    )
    assert_not_nil session.created_at
    assert_not_nil session.updated_at
  end

  test "session can be destroyed" do
    session = Session.create!(
      user: users(:charlie),
      ip_address: "192.168.1.1"
    )
    assert_difference "Session.count", -1 do
      session.destroy
    end
  end

  test "session persists across reloads" do
    session = Session.create!(
      user: users(:charlie),
      ip_address: "203.0.113.1",
      user_agent: "Test Browser"
    )
    session_id = session.id

    reloaded_session = Session.find(session_id)
    assert_equal session.user, reloaded_session.user
    assert_equal session.ip_address, reloaded_session.ip_address
    assert_equal session.user_agent, reloaded_session.user_agent
  end
end

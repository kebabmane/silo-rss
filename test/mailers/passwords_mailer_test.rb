require "test_helper"

class PasswordsMailerTest < ActionMailer::TestCase
  test "reset email" do
    user = users(:alice)
    email = PasswordsMailer.reset(user)

    # Test headers
    assert_emails 1 do
      email.deliver_now
    end

    assert_equal ["noreply@example.com"], email.from
    assert_equal [user.email_address], email.to
    assert_equal "Reset your password", email.subject
  end

  test "reset email contains user instance variable" do
    user = users(:alice)
    email = PasswordsMailer.reset(user)

    # The email should be personalized for the user
    assert email.to.include?(user.email_address)
  end

  test "reset email with different users" do
    alice = users(:alice)
    bob = users(:bob)

    alice_email = PasswordsMailer.reset(alice)
    bob_email = PasswordsMailer.reset(bob)

    assert_equal [alice.email_address], alice_email.to
    assert_equal [bob.email_address], bob_email.to
  end

  test "reset email can be delivered" do
    user = users(:alice)
    email = PasswordsMailer.reset(user)

    assert_nothing_raised do
      email.deliver_now
    end
  end

  test "reset email is added to delivery queue" do
    user = users(:alice)

    assert_emails 1 do
      PasswordsMailer.reset(user).deliver_now
    end
  end

  test "reset email can be delivered later" do
    user = users(:alice)

    assert_enqueued_emails 1 do
      PasswordsMailer.reset(user).deliver_later
    end
  end

  test "reset email with normalized email address" do
    user = User.create!(email_address: "TEST@EXAMPLE.COM", password: "password123")
    email = PasswordsMailer.reset(user)

    # Email should be sent to normalized (lowercase) address
    assert_equal ["test@example.com"], email.to
  end
end

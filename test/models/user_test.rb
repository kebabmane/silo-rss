require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid user" do
    user = User.new(email_address: "test@example.com", password: "password123")
    assert user.valid?
  end

  test "requires email_address" do
    user = User.new(password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email_address], "can't be blank"
  end

  test "requires password" do
    user = User.new(email_address: "test@example.com")
    assert_not user.valid?
    assert_includes user.errors[:password], "can't be blank"
  end

  test "normalizes email_address by stripping whitespace" do
    user = User.create!(email_address: "  test@example.com  ", password: "password123")
    assert_equal "test@example.com", user.email_address
  end

  test "normalizes email_address to lowercase" do
    user = User.create!(email_address: "TEST@EXAMPLE.COM", password: "password123")
    assert_equal "test@example.com", user.email_address
  end

  test "requires unique email_address" do
    User.create!(email_address: "test@example.com", password: "password123")
    duplicate_user = User.new(email_address: "test@example.com", password: "password456")
    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:email_address], "has already been taken"
  end

  test "has secure password" do
    user = users(:alice)
    assert user.authenticate("password")
    assert_not user.authenticate("wrong_password")
  end

  test "confirm! issues api token" do
    user = User.create!(email_address: "new@example.com", password: "password123")
    assert_nil user.confirmed_at
    assert_nil user.api_token

    token = user.confirm!(confirmed_by: users(:alice))
    assert user.confirmed?
    assert_not_nil token
    assert_equal 64, token.length
    assert_equal token, user.reload.api_token
  end

  test "issue_api_token! raises for unconfirmed user" do
    user = users(:pending)
    assert_raises(User::UnconfirmedUserError) { user.issue_api_token! }
  end

  test "regenerate_api_token! creates new token" do
    user = users(:alice)
    old_token = user.api_token
    user.regenerate_api_token!
    assert_not_equal old_token, user.reload.api_token
    assert_equal 64, user.api_token.length
  end

  test "has default theme of light" do
    user = User.new(email_address: "test@example.com", password: "password123")
    assert_equal "light", user.theme
  end

  test "can set custom theme" do
    user = User.create!(email_address: "test@example.com", password: "password123", theme: "dark")
    assert_equal "dark", user.theme
  end

  # Association tests
  test "has many sessions" do
    user = users(:alice)
    assert_respond_to user, :sessions
    assert_kind_of ActiveRecord::Associations::CollectionProxy, user.sessions
  end

  test "destroys sessions when user is destroyed" do
    user = users(:alice)
    session = user.sessions.create!
    assert_difference "Session.count", -2 do
      user.destroy
    end
  end

  test "has many subscriptions" do
    user = users(:alice)
    assert_respond_to user, :subscriptions
    assert user.subscriptions.count > 0
  end

  test "destroys subscriptions when user is destroyed" do
    user = users(:alice)
    subscription_count = user.subscriptions.count
    assert_difference "Subscription.count", -subscription_count do
      user.destroy
    end
  end

  test "has many feeds through subscriptions" do
    user = users(:alice)
    assert_respond_to user, :feeds
    assert user.feeds.count > 0
    assert_kind_of Feed, user.feeds.first
  end

  test "has many article_states" do
    user = users(:alice)
    assert_respond_to user, :article_states
    assert user.article_states.count > 0
  end

  test "destroys article_states when user is destroyed" do
    user = users(:alice)
    article_state_count = user.article_states.count
    assert_difference "ArticleState.count", -article_state_count do
      user.destroy
    end
  end
end

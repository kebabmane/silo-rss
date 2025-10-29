require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  test "valid subscription" do
    subscription = Subscription.new(
      user: users(:alice),
      feed: feeds(:ruby_weekly),
      category: "Technology"
    )
    assert subscription.valid?
  end

  # Validation tests
  test "allows category to be nil" do
    subscription = Subscription.new(
      user: users(:alice),
      feed: feeds(:ruby_weekly),
      category: nil
    )

    assert subscription.valid?
  end

  test "allows category to be blank string" do
    subscription = Subscription.new(
      user: users(:alice),
      feed: feeds(:ruby_weekly),
      category: ""
    )

    assert subscription.valid?
  end

  test "requires unique user_id scoped to feed_id" do
    subscription = subscriptions(:alice_tech_crunch)
    duplicate = Subscription.new(
      user: subscription.user,
      feed: subscription.feed,
      category: "Duplicate"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:user_id], "has already been taken"
  end

  test "allows same user to subscribe to different feeds" do
    user = users(:alice)
    subscription1 = subscriptions(:alice_tech_crunch)
    subscription2 = Subscription.new(
      user: user,
      feed: feeds(:ruby_weekly),
      category: "Programming"
    )
    assert subscription2.valid?
  end

  test "allows different users to subscribe to same feed" do
    feed = feeds(:tech_crunch)
    subscription1 = subscriptions(:alice_tech_crunch)
    subscription2 = Subscription.new(
      user: users(:charlie),
      feed: feed,
      category: "News"
    )
    assert subscription2.valid?
  end

  test "allows custom_name to be nil" do
    subscription = Subscription.new(
      user: users(:alice),
      feed: feeds(:ruby_weekly),
      category: "Technology",
      custom_name: nil
    )
    assert subscription.valid?
  end

  test "allows custom_name to be set" do
    subscription = Subscription.new(
      user: users(:alice),
      feed: feeds(:ruby_weekly),
      category: "Technology",
      custom_name: "My Custom Feed Name"
    )
    assert subscription.valid?
    assert_equal "My Custom Feed Name", subscription.custom_name
  end

  # Association tests
  test "belongs to user" do
    subscription = subscriptions(:alice_tech_crunch)
    assert_respond_to subscription, :user
    assert_kind_of User, subscription.user
    assert_equal users(:alice), subscription.user
  end

  test "belongs to feed" do
    subscription = subscriptions(:alice_tech_crunch)
    assert_respond_to subscription, :feed
    assert_kind_of Feed, subscription.feed
    assert_equal feeds(:tech_crunch), subscription.feed
  end

  test "requires user" do
    subscription = Subscription.new(
      feed: feeds(:tech_crunch),
      category: "Technology"
    )
    assert_not subscription.valid?
    assert_includes subscription.errors[:user], "must exist"
  end

  test "requires feed" do
    subscription = Subscription.new(
      user: users(:alice),
      category: "Technology"
    )
    assert_not subscription.valid?
    assert_includes subscription.errors[:feed], "must exist"
  end

  # Instance method tests
  test "display_name returns custom_name when set" do
    subscription = subscriptions(:alice_hacker_news)
    assert_equal "HN - Custom Name", subscription.custom_name
    assert_equal "HN - Custom Name", subscription.display_name
  end

  test "display_name returns feed title when custom_name is nil" do
    subscription = subscriptions(:alice_tech_crunch)
    assert_nil subscription.custom_name
    assert_equal subscription.feed.title, subscription.display_name
  end

  test "display_name returns feed title when custom_name is empty string" do
    subscription = Subscription.create!(
      user: users(:charlie),
      feed: feeds(:hacker_news),
      category: "News",
      custom_name: ""
    )
    assert_equal subscription.feed.title, subscription.display_name
  end

  test "display_name returns feed title when custom_name is whitespace only" do
    subscription = Subscription.create!(
      user: users(:charlie),
      feed: feeds(:hacker_news),
      category: "News",
      custom_name: "   "
    )
    assert_equal subscription.feed.title, subscription.display_name
  end

  # Edge case tests
  test "can update category" do
    subscription = subscriptions(:alice_tech_crunch)
    original_category = subscription.category
    subscription.update!(category: "Updated Category")
    assert_equal "Updated Category", subscription.reload.category
    assert_not_equal original_category, subscription.category
  end

  test "can update custom_name" do
    subscription = subscriptions(:alice_tech_crunch)
    subscription.update!(custom_name: "New Name")
    assert_equal "New Name", subscription.reload.custom_name
  end

  test "can remove custom_name by setting to nil" do
    subscription = subscriptions(:alice_hacker_news)
    assert_not_nil subscription.custom_name
    subscription.update!(custom_name: nil)
    assert_nil subscription.reload.custom_name
    assert_equal subscription.feed.title, subscription.display_name
  end

  test "category can contain special characters" do
    subscription = Subscription.create!(
      user: users(:charlie),
      feed: feeds(:tech_crunch),
      category: "Tech & Science"
    )
    assert subscription.valid?
    assert_equal "Tech & Science", subscription.category
  end

  test "custom_name can contain special characters" do
    subscription = Subscription.create!(
      user: users(:charlie),
      feed: feeds(:tech_crunch),
      category: "Technology",
      custom_name: "Tech Crunch & Co."
    )
    assert subscription.valid?
    assert_equal "Tech Crunch & Co.", subscription.custom_name
  end

  test "category can be very long" do
    long_category = "A" * 255
    subscription = Subscription.create!(
      user: users(:charlie),
      feed: feeds(:tech_crunch),
      category: long_category
    )
    assert subscription.valid?
    assert_equal long_category, subscription.category
  end
end

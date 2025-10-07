require "test_helper"

class FeedTest < ActiveSupport::TestCase
  test "valid feed" do
    feed = Feed.new(
      title: "Test Feed",
      feed_url: "https://example.com/feed.xml",
      site_url: "https://example.com"
    )
    assert feed.valid?
  end

  test "requires title" do
    feed = Feed.new(feed_url: "https://example.com/feed.xml")
    assert_not feed.valid?
    assert_includes feed.errors[:title], "can't be blank"
  end

  test "requires feed_url" do
    feed = Feed.new(title: "Test Feed")
    assert_not feed.valid?
    assert_includes feed.errors[:feed_url], "can't be blank"
  end

  test "requires unique feed_url" do
    Feed.create!(title: "Test Feed", feed_url: "https://example.com/feed.xml")
    duplicate_feed = Feed.new(title: "Another Feed", feed_url: "https://example.com/feed.xml")
    assert_not duplicate_feed.valid?
    assert_includes duplicate_feed.errors[:feed_url], "has already been taken"
  end

  test "allows same title for different feeds" do
    Feed.create!(title: "Same Title", feed_url: "https://example1.com/feed.xml")
    feed2 = Feed.new(title: "Same Title", feed_url: "https://example2.com/feed.xml")
    assert feed2.valid?
  end

  # Association tests
  test "has many articles" do
    feed = feeds(:tech_crunch)
    assert_respond_to feed, :articles
    assert feed.articles.count > 0
  end

  test "destroys articles when feed is destroyed" do
    feed = feeds(:tech_crunch)
    article_count = feed.articles.count
    assert article_count > 0
    assert_difference "Article.count", -article_count do
      feed.destroy
    end
  end

  test "has many subscriptions" do
    feed = feeds(:tech_crunch)
    assert_respond_to feed, :subscriptions
    assert feed.subscriptions.count > 0
  end

  test "destroys subscriptions when feed is destroyed" do
    feed = feeds(:tech_crunch)
    subscription_count = feed.subscriptions.count
    assert subscription_count > 0
    assert_difference "Subscription.count", -subscription_count do
      feed.destroy
    end
  end

  test "has many users through subscriptions" do
    feed = feeds(:tech_crunch)
    assert_respond_to feed, :users
    assert feed.users.count > 0
    assert_kind_of User, feed.users.first
  end
end

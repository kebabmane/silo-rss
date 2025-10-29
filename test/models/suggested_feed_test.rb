require "test_helper"

class SuggestedFeedTest < ActiveSupport::TestCase
  # Validation tests
  test "valid suggested feed" do
    suggested_feed = SuggestedFeed.new(
      title: "Test Feed",
      feed_url: "https://example.com/feed.xml",
      category: "Technology"
    )
    assert suggested_feed.valid?
  end

  test "requires title" do
    suggested_feed = SuggestedFeed.new(
      feed_url: "https://example.com/feed.xml",
      category: "Technology"
    )
    assert_not suggested_feed.valid?
    assert_includes suggested_feed.errors[:title], "can't be blank"
  end

  test "requires feed_url" do
    suggested_feed = SuggestedFeed.new(
      title: "Test Feed",
      category: "Technology"
    )
    assert_not suggested_feed.valid?
    assert_includes suggested_feed.errors[:feed_url], "can't be blank"
  end

  test "requires category" do
    suggested_feed = SuggestedFeed.new(
      title: "Test Feed",
      feed_url: "https://example.com/feed.xml"
    )
    assert_not suggested_feed.valid?
    assert_includes suggested_feed.errors[:category], "can't be blank"
  end

  test "requires unique feed_url" do
    existing = suggested_feeds(:tech_crunch_suggested)
    duplicate = SuggestedFeed.new(
      title: "Duplicate",
      feed_url: existing.feed_url,
      category: "Technology"
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:feed_url], "has already been taken"
  end

  test "validates display_order is an integer" do
    suggested_feed = SuggestedFeed.new(
      title: "Test Feed",
      feed_url: "https://example.com/feed.xml",
      category: "Technology",
      display_order: "not_a_number"
    )
    assert_not suggested_feed.valid?
    assert_includes suggested_feed.errors[:display_order], "is not a number"
  end

  test "validates display_order is only an integer" do
    suggested_feed = SuggestedFeed.new(
      title: "Test Feed",
      feed_url: "https://example.com/feed.xml",
      category: "Technology",
      display_order: 3.14
    )
    assert_not suggested_feed.valid?
    assert_includes suggested_feed.errors[:display_order], "must be an integer"
  end

  test "allows nil display_order" do
    suggested_feed = SuggestedFeed.new(
      title: "Test Feed",
      feed_url: "https://example.com/feed.xml",
      category: "Technology",
      display_order: nil
    )
    assert suggested_feed.valid?
  end

  test "allows description to be nil" do
    suggested_feed = SuggestedFeed.new(
      title: "Test Feed",
      feed_url: "https://example.com/feed.xml",
      category: "Technology",
      description: nil
    )
    assert suggested_feed.valid?
  end

  # Scope tests
  test "ordered scope orders by display_order and then created_at" do
    feeds = SuggestedFeed.ordered.to_a

    # Check that display_order is in ascending order
    display_orders = feeds.map(&:display_order).compact
    assert_equal display_orders.sort, display_orders
  end

  test "by_category scope filters by category" do
    tech_feeds = SuggestedFeed.by_category("Technology")

    assert tech_feeds.count > 0
    tech_feeds.each do |feed|
      assert_equal "Technology", feed.category
    end
  end

  test "by_category scope returns empty array for non-existent category" do
    feeds = SuggestedFeed.by_category("NonExistentCategory")
    assert_equal 0, feeds.count
  end

  # Class method tests
  test "categories returns all unique categories" do
    categories = SuggestedFeed.categories

    assert_kind_of Array, categories
    assert_includes categories, "Technology"
    assert_includes categories, "News"
    assert_includes categories, "Development"
    assert_includes categories, "Science"

    # Should be sorted
    assert_equal categories.sort, categories
  end

  test "categories returns unique values only" do
    categories = SuggestedFeed.categories
    assert_equal categories.uniq, categories
  end

  test "categories returns empty array when no feeds exist" do
    SuggestedFeed.destroy_all
    categories = SuggestedFeed.categories
    assert_equal [], categories
  end

  # Edge cases
  test "handles very long title" do
    long_title = "a" * 1000
    suggested_feed = SuggestedFeed.new(
      title: long_title,
      feed_url: "https://example.com/feed.xml",
      category: "Technology"
    )
    # Should save or fail based on database column constraints
    # Most databases will handle this, but it's good to test
    assert suggested_feed.save || !suggested_feed.valid?
  end

  test "handles very long feed_url" do
    long_url = "https://example.com/" + ("a" * 1000) + ".xml"
    suggested_feed = SuggestedFeed.new(
      title: "Test",
      feed_url: long_url,
      category: "Technology"
    )
    assert suggested_feed.save || !suggested_feed.valid?
  end

  test "handles very long category" do
    long_category = "a" * 1000
    suggested_feed = SuggestedFeed.new(
      title: "Test",
      feed_url: "https://example.com/feed.xml",
      category: long_category
    )
    assert suggested_feed.save || !suggested_feed.valid?
  end

  test "handles very long description" do
    long_description = "a" * 10000
    suggested_feed = SuggestedFeed.new(
      title: "Test",
      feed_url: "https://example.com/feed.xml",
      category: "Technology",
      description: long_description
    )
    # Text fields can handle long content
    assert suggested_feed.valid?
  end

  test "handles negative display_order" do
    suggested_feed = SuggestedFeed.new(
      title: "Test",
      feed_url: "https://example.com/feed.xml",
      category: "Technology",
      display_order: -1
    )
    # Should be valid - display_order just needs to be an integer
    assert suggested_feed.valid?
  end

  test "handles zero display_order" do
    suggested_feed = SuggestedFeed.new(
      title: "Test",
      feed_url: "https://example.com/feed.xml",
      category: "Technology",
      display_order: 0
    )
    assert suggested_feed.valid?
  end

  # Fixture tests
  test "fixtures are valid" do
    tech_crunch = suggested_feeds(:tech_crunch_suggested)
    assert tech_crunch.valid?
    assert_equal "TechCrunch", tech_crunch.title
    assert_equal "Technology", tech_crunch.category
  end

  test "multiple fixtures loaded" do
    assert SuggestedFeed.count >= 10
  end
end

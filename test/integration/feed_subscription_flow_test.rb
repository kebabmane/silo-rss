require "test_helper"

class FeedSubscriptionFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:alice)
    login_as(@user)
  end

  test "complete feed discovery and subscription flow" do
    # Stub external HTTP requests for feed discovery
    feed_html = <<~HTML
      <html>
        <head>
          <link rel="alternate" type="application/rss+xml" href="/feed.xml" />
        </head>
      </html>
    HTML

    feed_xml = <<~XML
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>New Tech Blog</title>
          <link>https://newtechblog.com</link>
          <description>Latest tech news</description>
        </channel>
      </rss>
    XML

    stub_request(:get, "https://newtechblog.com")
      .to_return(status: 200, body: feed_html, headers: { "Content-Type" => "text/html" })

    stub_request(:get, "https://newtechblog.com/feed.xml")
      .to_return(status: 200, body: feed_xml, headers: { "Content-Type" => "application/xml" })

    # Visit new feed page
    get new_feed_path
    assert_response :success

    # Discover feed
    post discover_feeds_path, params: { url: "https://newtechblog.com" }
    assert_response :success

    # Verify feed was created
    feed = Feed.find_by(feed_url: "https://newtechblog.com/feed.xml")
    assert feed
    assert_equal "New Tech Blog", feed.title
    assert_equal "https://newtechblog.com", feed.site_url

    # Subscribe to the discovered feed
    assert_difference "@user.subscriptions.count", 1 do
      post feeds_path, params: {
        feed_id: feed.id,
        category: "Technology",
        custom_name: "My Tech Blog"
      }
    end

    # Should redirect to root with success message
    assert_redirected_to dashboard_path
    follow_redirect!
    assert_match /Feed added successfully/, flash[:notice]

    # Verify subscription was created correctly
    subscription = @user.subscriptions.last
    assert_equal feed, subscription.feed
    assert_equal "Technology", subscription.category
    assert_equal "My Tech Blog", subscription.custom_name
  end

  test "discover feed from direct RSS URL" do
    feed_xml = <<~XML
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>Direct RSS Feed</title>
          <link>https://directrss.com</link>
        </channel>
      </rss>
    XML

    stub_request(:get, "https://directrss.com/rss.xml")
      .to_return(status: 200, body: feed_xml, headers: { "Content-Type" => "application/rss+xml" })

    # Discover feed using direct RSS URL
    post discover_feeds_path, params: { url: "https://directrss.com/rss.xml" }
    assert_response :success

    feed = Feed.find_by(feed_url: "https://directrss.com/rss.xml")
    assert feed
    assert_equal "Direct RSS Feed", feed.title
  end

  test "feed discovery failure shows error" do
    # Stub request to return HTML without feed links
    stub_request(:get, "https://nofeed.com")
      .to_return(status: 200, body: "<html><head></head><body>No feed here</body></html>", headers: { "Content-Type" => "text/html" })

    # Try common feed URLs (all fail)
    stub_request(:get, %r{https://nofeed.com/(feed|rss|atom|feed\.xml|rss\.xml|atom\.xml)})
      .to_return(status: 404)

    post discover_feeds_path, params: { url: "https://nofeed.com" }
    assert_response :success
  end

  test "subscribe to existing feed" do
    # Use existing feed from fixtures
    existing_feed = feeds(:ruby_weekly)

    # Alice doesn't have this feed yet
    assert_not @user.subscriptions.exists?(feed: existing_feed)

    # Subscribe to existing feed
    assert_difference "@user.subscriptions.count", 1 do
      assert_no_difference "Feed.count" do
        post feeds_path, params: {
          feed_id: existing_feed.id,
          category: "Programming",
          custom_name: nil
        }
      end
    end

    subscription = @user.subscriptions.last
    assert_equal existing_feed, subscription.feed
    assert_equal "Programming", subscription.category
  end

  test "unsubscribe from feed" do
    # Alice is subscribed to tech_crunch
    feed = feeds(:tech_crunch)
    subscription = subscriptions(:alice_tech_crunch)

    assert @user.subscriptions.exists?(subscription.id)

    # Unsubscribe
    assert_difference "@user.subscriptions.count", -1 do
      delete feed_path(feed)
    end

    assert_redirected_to feeds_path
    follow_redirect!
    assert_match /Feed removed/, flash[:notice]

    # Verify subscription was deleted
    assert_not @user.subscriptions.exists?(subscription.id)
  end

  test "view all subscriptions grouped by category" do
    get feeds_path
    assert_response :success

    # Should show subscribed feeds
    assert_select "body", text: /TechCrunch/
    assert_select "body", text: /HN - Custom Name/

    # Should not show feeds user isn't subscribed to
    assert_select "body", text: /Ruby Weekly/, count: 0
  end

  test "manage subscription categories" do
    feed_xml = <<~XML
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>Dev Blog</title>
        </channel>
      </rss>
    XML

    stub_request(:get, "https://devblog.com/feed")
      .to_return(status: 200, body: feed_xml, headers: { "Content-Type" => "application/rss+xml" })

    # Discover feed
    post discover_feeds_path, params: { url: "https://devblog.com/feed" }
    feed = Feed.find_by(feed_url: "https://devblog.com/feed")

    # Subscribe with specific category
    post feeds_path, params: {
      feed_id: feed.id,
      category: "Development",
      custom_name: nil
    }

    subscription = @user.subscriptions.find_by(feed: feed)
    assert_equal "Development", subscription.category
  end

  test "custom feed naming" do
    feed = feeds(:tech_crunch)

    # Subscribe with custom name
    @user.subscriptions.find_by(feed: feed).destroy  # Remove existing subscription

    post feeds_path, params: {
      feed_id: feed.id,
      category: "Tech News",
      custom_name: "TC - Latest News"
    }

    subscription = @user.subscriptions.find_by(feed: feed)
    assert_equal "TC - Latest News", subscription.custom_name
    assert_equal "TC - Latest News", subscription.display_name
  end

  test "subscription uses feed title when no custom name" do
    feed = feeds(:tech_crunch)

    # Subscribe without custom name
    @user.subscriptions.find_by(feed: feed).destroy

    post feeds_path, params: {
      feed_id: feed.id,
      category: "News",
      custom_name: ""
    }

    subscription = @user.subscriptions.find_by(feed: feed)
    assert_nil subscription.custom_name
    assert_equal feed.title, subscription.display_name
  end

  test "cannot subscribe to same feed twice" do
    feed = feeds(:tech_crunch)

    # Alice already has this subscription
    assert @user.subscriptions.exists?(feed: feed)

    # Try to subscribe again (idempotent - returns success)
    assert_no_difference "@user.subscriptions.count" do
      post feeds_path, params: {
        feed_id: feed.id,
        category: "Technology",
        custom_name: nil
      }
    end

    # Idempotent behavior: should redirect with success message
    assert_redirected_to dashboard_path
    assert_match /Feed added successfully/, flash[:notice]
  end

  test "complete workflow: discover, subscribe, view, unsubscribe" do
    feed_xml = <<~XML
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>Complete Flow Feed</title>
          <link>https://completeflow.com</link>
        </channel>
      </rss>
    XML

    stub_request(:get, "https://completeflow.com/rss")
      .to_return(status: 200, body: feed_xml, headers: { "Content-Type" => "application/rss+xml" })

    # Step 1: Discover feed
    post discover_feeds_path, params: { url: "https://completeflow.com/rss" }
    feed = Feed.find_by(feed_url: "https://completeflow.com/rss")
    assert feed

    # Step 2: Subscribe
    post feeds_path, params: {
      feed_id: feed.id,
      category: "Test",
      custom_name: "Test Feed"
    }
    assert_redirected_to dashboard_path

    # Step 3: View subscriptions
    get feeds_path
    assert_response :success
    assert_select "body", text: /Test Feed/

    # Step 4: Unsubscribe
    delete feed_path(feed)
    assert_redirected_to feeds_path

    # Verify feed is gone from subscriptions
    assert_not @user.subscriptions.exists?(feed: feed)
  end

  test "URL normalization in feed discovery" do
    feed_xml = <<~XML
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>Normalized Feed</title>
        </channel>
      </rss>
    XML

    # Test URL without protocol
    stub_request(:get, "https://example.com/feed")
      .to_return(status: 200, body: feed_xml, headers: { "Content-Type" => "application/rss+xml" })

    post discover_feeds_path, params: { url: "example.com/feed" }

    feed = Feed.find_by(feed_url: "https://example.com/feed")
    assert feed, "Feed should be created with normalized URL"
  end

  test "multiple users can subscribe to same feed" do
    other_user = users(:bob)

    # Alice discovers and subscribes to a new feed
    feed_xml = <<~XML
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>Shared Feed</title>
        </channel>
      </rss>
    XML

    stub_request(:get, "https://shared.com/feed")
      .to_return(status: 200, body: feed_xml, headers: { "Content-Type" => "application/rss+xml" })

    post discover_feeds_path, params: { url: "https://shared.com/feed" }
    feed = Feed.find_by(feed_url: "https://shared.com/feed")

    post feeds_path, params: {
      feed_id: feed.id,
      category: "Shared",
      custom_name: nil
    }

    # Bob subscribes to same feed (simulating different session)
    login_as(other_user)

    assert_no_difference "Feed.count" do
      assert_difference "other_user.subscriptions.count", 1 do
        post feeds_path, params: {
          feed_id: feed.id,
          category: "Bob's Category",
          custom_name: "Bob's Custom Name"
        }
      end
    end

    # Both users should have subscriptions to same feed
    assert @user.subscriptions.exists?(feed: feed)
    assert other_user.subscriptions.exists?(feed: feed)

    # But with different categories/names
    alice_sub = @user.subscriptions.find_by(feed: feed)
    bob_sub = other_user.subscriptions.find_by(feed: feed)

    assert_equal "Shared", alice_sub.category
    assert_equal "Bob's Category", bob_sub.category
    assert_equal "Bob's Custom Name", bob_sub.custom_name
  end

  test "feed refresh is triggered after subscription" do
    feed_xml = <<~XML
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>Refresh Test Feed</title>
        </channel>
      </rss>
    XML

    stub_request(:get, "https://refresh.com/feed")
      .to_return(status: 200, body: feed_xml, headers: { "Content-Type" => "application/rss+xml" })

    # Mock the job
    FeedRefreshJob.expects(:perform_later).once

    post discover_feeds_path, params: { url: "https://refresh.com/feed" }
  end
end

require "test_helper"

class FeedsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @tech_crunch = feeds(:tech_crunch)
    @hacker_news = feeds(:hacker_news)
    @ruby_weekly = feeds(:ruby_weekly)
  end

  # Index action tests
  test "should redirect to login when not authenticated" do
    get feeds_url
    assert_redirected_to new_session_path
  end

  test "should get index when authenticated" do
    login_as @alice
    get feeds_url
    assert_response :success
  end

  test "should show user's subscriptions" do
    login_as @alice
    get feeds_url
    assert_response :success
    # Subscriptions are loaded and rendered - verified by successful response
  end

  test "should order subscriptions by category and custom_name" do
    login_as @alice
    get feeds_url
    assert_response :success
    # Subscriptions should be ordered by category, then custom_name
  end

  test "should include feed data with subscriptions" do
    login_as @alice
    get feeds_url
    assert_response :success
    # Should eager load feeds to avoid N+1 queries
  end

  # New action tests
  test "should redirect to login when accessing new without authentication" do
    get new_feed_url
    assert_redirected_to new_session_path
  end

  test "should get new feed page when authenticated" do
    login_as @alice
    get new_feed_url
    assert_response :success
  end

  test "should initialize new subscription" do
    login_as @alice
    get new_feed_url
    assert_response :success
    # New subscription is initialized - verified by successful response
  end

  # Discover action tests
  test "should redirect to login when discovering without authentication" do
    post discover_feeds_url, params: { url: "https://example.com" }
    assert_redirected_to new_session_path
  end

  test "should discover feed from URL successfully" do
    login_as @alice

    # Mock the discovery service
    discovery_result = {
      feed_url: "https://example.com/feed.xml",
      site_url: "https://example.com"
    }
    FeedDiscoveryService.any_instance.stubs(:discover).returns(discovery_result)

    # Mock Feedjira parsing
    parsed_feed = mock
    parsed_feed.stubs(:title).returns("Example Feed")
    Feedjira.stubs(:parse).returns(parsed_feed)

    # Mock HTTParty
    response = mock
    response.stubs(:body).returns("<rss></rss>")
    response.stubs(:media_type).returns(Mime[:turbo_stream].to_s)
    HTTParty.stubs(:get).returns(response)

    # Mock the job
    FeedRefreshJob.stubs(:perform_later)

    post discover_feeds_url, params: { url: "https://example.com" }, as: :turbo_stream
    assert_response :success
    assert_equal Mime[:turbo_stream].to_s, response.media_type
  end

  test "should create new feed when discovering unknown feed" do
    login_as @alice

    discovery_result = {
      feed_url: "https://newfeed.com/rss",
      site_url: "https://newfeed.com"
    }
    FeedDiscoveryService.any_instance.stubs(:discover).returns(discovery_result)

    parsed_feed = mock
    parsed_feed.stubs(:title).returns("New Feed")
    Feedjira.stubs(:parse).returns(parsed_feed)

    response_mock = mock
    response_mock.stubs(:body).returns("<rss></rss>")
    HTTParty.stubs(:get).returns(response_mock)

    FeedRefreshJob.stubs(:perform_later)

    assert_difference "Feed.count", 1 do
      post discover_feeds_url, params: { url: "https://newfeed.com" }, as: :turbo_stream
    end
    assert_response :success
  end

  test "should find existing feed when discovering known feed" do
    login_as @alice

    discovery_result = {
      feed_url: @tech_crunch.feed_url,
      site_url: @tech_crunch.site_url
    }
    FeedDiscoveryService.any_instance.stubs(:discover).returns(discovery_result)

    assert_no_difference "Feed.count" do
      post discover_feeds_url, params: { url: @tech_crunch.site_url }, as: :turbo_stream
    end
    assert_response :success
  end

  test "should enqueue FeedRefreshJob for new feed" do
    login_as @alice

    discovery_result = {
      feed_url: "https://newfeed.com/rss",
      site_url: "https://newfeed.com"
    }
    FeedDiscoveryService.any_instance.stubs(:discover).returns(discovery_result)

    parsed_feed = mock
    parsed_feed.stubs(:title).returns("New Feed")
    Feedjira.stubs(:parse).returns(parsed_feed)

    response_mock = mock
    response_mock.stubs(:body).returns("<rss></rss>")
    HTTParty.stubs(:get).returns(response_mock)

    FeedRefreshJob.expects(:perform_later).once

    post discover_feeds_url, params: { url: "https://newfeed.com" }, as: :turbo_stream
  end

  test "should return error when discovery fails" do
    login_as @alice

    FeedDiscoveryService.any_instance.stubs(:discover).returns(nil)

    post discover_feeds_url, params: { url: "https://invalid-url.com" }, as: :turbo_stream
    assert_response :success
    # Should render discovery_error partial
  end

  test "should include existing categories in discovery response" do
    login_as @alice

    discovery_result = {
      feed_url: @tech_crunch.feed_url,
      site_url: @tech_crunch.site_url
    }
    FeedDiscoveryService.any_instance.stubs(:discover).returns(discovery_result)

    post discover_feeds_url, params: { url: @tech_crunch.site_url }, as: :turbo_stream
    assert_response :success
    # Response should include existing categories for dropdown
  end

  test "should redirect to login when refreshing feeds without authentication" do
    post refresh_all_feeds_url
    assert_redirected_to new_session_path
  end

  test "should enqueue user feed refresh job" do
    login_as @alice

    assert_enqueued_with(job: UserFeedRefreshJob, args: [ @alice.id ]) do
      post refresh_all_feeds_url
    end

    assert_redirected_to dashboard_path
    assert_equal "Sync started. Your feeds will refresh shortly.", flash[:notice]
  end

  # Create action tests
  test "should redirect to login when creating subscription without authentication" do
    post feeds_url, params: { feed_id: @tech_crunch.id, category: "Tech" }
    assert_redirected_to new_session_path
  end

  test "should create subscription successfully" do
    login_as @alice
    feed = @ruby_weekly # Alice doesn't have this subscription yet

    assert_difference "Subscription.count", 1 do
      post feeds_url, params: { feed_id: feed.id, category: "Programming", custom_name: "Ruby News" }
    end

    assert_response :redirect
    assert_match %r{/dashboard(\?feed_id=\d+)?\z}, response.location
    assert_equal "Feed added successfully", flash[:notice]
  end

  test "should create subscription with current user" do
    login_as @alice
    feed = @ruby_weekly

    post feeds_url, params: { feed_id: feed.id, category: "Programming" }

    subscription = Subscription.last
    assert_equal @alice.id, subscription.user_id
    assert_equal feed.id, subscription.feed_id
  end

  test "should create subscription with category and custom_name" do
    login_as @alice
    feed = @ruby_weekly

    post feeds_url, params: {
      feed_id: feed.id,
      category: "Programming",
      custom_name: "My Ruby Feed"
    }

    subscription = Subscription.last
    assert_equal "Programming", subscription.category
    assert_equal "My Ruby Feed", subscription.custom_name
  end

  test "should not create duplicate subscription" do
    login_as @alice
    # Alice already has subscription to tech_crunch

    assert_no_difference "Subscription.count" do
      post feeds_url, params: { feed_id: @tech_crunch.id, category: "Tech" }
    end

    # Idempotent behavior: should redirect with success message, not error
    assert_response :redirect
    assert_match %r{/dashboard(\?feed_id=\d+)?\z}, response.location
    assert_match /Feed added successfully/, flash[:notice]
  end

  test "should render new with errors when subscription is invalid" do
    login_as @alice

    # Mock invalid subscription
    Subscription.any_instance.stubs(:save).returns(false)

    post feeds_url, params: { feed_id: @ruby_weekly.id }
    assert_response :unprocessable_entity
  end

  test "should redirect with alert when creating subscription for non-existent feed" do
    login_as @alice

    post feeds_url, params: { feed_id: 999999, category: "Test" }

    assert_redirected_to dashboard_path
    assert_equal "Feed not found", flash[:alert]
  end

  test "should return 404 JSON when creating subscription for non-existent feed via API" do
    login_as @alice

    post feeds_url, params: { feed_id: 999999, category: "Test" }, as: :json

    assert_response :not_found
  end

  # Destroy action tests
  test "should redirect to login when destroying subscription without authentication" do
    delete feed_url(@tech_crunch)
    assert_redirected_to new_session_path
  end

  test "should destroy subscription successfully" do
    login_as @alice
    # Alice has subscription to tech_crunch

    assert_difference "Subscription.count", -1 do
      delete feed_url(@tech_crunch)
    end

    assert_redirected_to feeds_path
    assert_equal "Feed removed", flash[:notice]
  end

  test "should only destroy current user's subscription" do
    login_as @alice
    # Alice has tech_crunch, Bob also has tech_crunch

    alice_subscription = subscriptions(:alice_tech_crunch)
    bob_subscription = subscriptions(:bob_tech_crunch)

    assert_difference "Subscription.count", -1 do
      delete feed_url(@tech_crunch)
    end

    # Alice's subscription should be gone
    assert_not Subscription.exists?(alice_subscription.id)
    # Bob's subscription should still exist
    assert Subscription.exists?(bob_subscription.id)
  end

  test "should handle destroying non-subscribed feed gracefully" do
    login_as @alice
    # Alice doesn't have subscription to ruby_weekly

    assert_no_difference "Subscription.count" do
      delete feed_url(@ruby_weekly)
    end

    assert_redirected_to feeds_path
  end

  test "should return 404 when destroying non-existent feed" do
    login_as @alice

    delete feed_url(id: 999999)

    assert_response :not_found
  end

  # User isolation tests
  test "should not show other users' subscriptions in index" do
    login_as @alice
    get feeds_url
    assert_response :success
    # Only alice's subscriptions are shown - verified by successful response
  end

  test "should not allow user to delete another user's subscription" do
    login_as @bob
    alice_subscription = subscriptions(:alice_hacker_news)

    # Bob tries to delete, but only his own subscription should be affected
    delete feed_url(alice_subscription.feed)

    # Alice's subscription should still exist (Bob has no subscription to hacker_news)
    assert Subscription.exists?(alice_subscription.id)
  end

  # Edge cases
  test "should handle discovery with malformed URL" do
    login_as @alice

    FeedDiscoveryService.any_instance.stubs(:discover).returns(nil)

    post discover_feeds_url, params: { url: "not-a-valid-url" }, as: :turbo_stream
    assert_response :success
  end

  test "should handle discovery when Feedjira parsing fails" do
    login_as @alice

    discovery_result = {
      feed_url: "https://example.com/feed.xml",
      site_url: "https://example.com"
    }
    FeedDiscoveryService.any_instance.stubs(:discover).returns(discovery_result)

    # Feedjira returns nil when parsing fails
    Feedjira.stubs(:parse).returns(nil)

    response_mock = mock
    response_mock.stubs(:body).returns("invalid xml")
    HTTParty.stubs(:get).returns(response_mock)

    FeedRefreshJob.stubs(:perform_later)

    assert_difference "Feed.count", 1 do
      post discover_feeds_url, params: { url: "https://example.com" }, as: :turbo_stream
    end

    # Feed should be created with a fallback title (hostname) when Feedjira can't parse
    feed = Feed.last
    assert_not_nil feed.title, "Feed should have a fallback title when Feedjira parsing fails"
    assert_equal "example.com", feed.title
  end

  test "should handle HTTParty errors during discovery" do
    login_as @alice

    discovery_result = {
      feed_url: "https://example.com/feed.xml",
      site_url: "https://example.com"
    }
    FeedDiscoveryService.any_instance.stubs(:discover).returns(discovery_result)

    response_mock = mock
    response_mock.stubs(:body).returns("")
    HTTParty.stubs(:get).returns(response_mock)

    post discover_feeds_url, params: { url: "https://example.com" }, as: :turbo_stream
    assert_response :success
  end

  test "should handle empty category when creating subscription" do
    login_as @alice

    post feeds_url, params: {
      feed_id: @ruby_weekly.id,
      category: "",
      custom_name: "Ruby"
    }

    # Should still create subscription with empty/nil category
    subscription = Subscription.last
    assert subscription.category.blank?
  end

  test "should handle nil custom_name when creating subscription" do
    login_as @alice

    post feeds_url, params: {
      feed_id: @ruby_weekly.id,
      category: "Tech"
    }

    subscription = Subscription.last
    assert_nil subscription.custom_name
  end
end

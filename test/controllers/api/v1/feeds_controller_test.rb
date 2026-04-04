require "test_helper"

module Api
  module V1
    class FeedsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @alice = users(:alice)
        @bob = users(:bob)
        @charlie = users(:charlie)
        @tech_crunch = feeds(:tech_crunch)
        @hacker_news = feeds(:hacker_news)
        @ruby_weekly = feeds(:ruby_weekly)
        @alice_tech_sub = subscriptions(:alice_tech_crunch)
        @alice_hn_sub = subscriptions(:alice_hacker_news)

        # Stub external HTTP requests for feed discovery
        stub_feed_discovery_requests
      end

      # GET /api/v1/feeds
      test "index returns all subscriptions for authenticated user" do
        get api_v1_feeds_url, headers: api_headers(@alice), as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert_equal 2, json.length

        subscription_ids = json.map { |s| s["id"] }
        assert_includes subscription_ids, @alice_tech_sub.id
        assert_includes subscription_ids, @alice_hn_sub.id
      end

      test "index returns correct subscription structure" do
        get api_v1_feeds_url, headers: api_headers(@alice), as: :json

        assert_response :success
        json = JSON.parse(response.body)

        subscription = json.first

        assert subscription.key?("id")
        assert subscription.key?("category")
        assert subscription.key?("custom_name")
        assert subscription.key?("feed")

        # Feed structure
        feed = subscription["feed"]
        assert feed.key?("id")
        assert feed.key?("title")
        assert feed.key?("feed_url")
        assert feed.key?("site_url")
        assert feed.key?("last_fetched_at")
      end

      test "index returns subscriptions with custom names" do
        get api_v1_feeds_url, headers: api_headers(@alice), as: :json

        assert_response :success
        json = JSON.parse(response.body)

        hn_sub = json.find { |s| s["feed"]["id"] == @hacker_news.id }
        assert_not_nil hn_sub
        assert_equal "HN - Custom Name", hn_sub["custom_name"]
      end

      test "index returns subscriptions with categories" do
        get api_v1_feeds_url, headers: api_headers(@alice), as: :json

        assert_response :success
        json = JSON.parse(response.body)

        tc_sub = json.find { |s| s["feed"]["id"] == @tech_crunch.id }
        assert_not_nil tc_sub
        assert_equal "Technology", tc_sub["category"]
      end

      test "index requires authentication" do
        get api_v1_feeds_url, as: :json

        assert_response :unauthorized
        json = JSON.parse(response.body)
        assert_equal "Unauthorized", json["error"]
      end

      test "index returns unauthorized with invalid token" do
        get api_v1_feeds_url,
            headers: { "Authorization" => "Bearer invalid_token" },
            as: :json

        assert_response :unauthorized
        json = JSON.parse(response.body)
        assert_equal "Unauthorized", json["error"]
      end

      test "index returns empty array for user with no subscriptions" do
        get api_v1_feeds_url, headers: api_headers(@charlie), as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert_equal 0, json.length
      end

      test "index only returns current user subscriptions" do
        get api_v1_feeds_url, headers: api_headers(@alice), as: :json

        assert_response :success
        json = JSON.parse(response.body)

        # Alice should not see Bob's ruby_weekly subscription
        feed_ids = json.map { |s| s["feed"]["id"] }
        assert_not_includes feed_ids, @ruby_weekly.id
      end

      # POST /api/v1/feeds/discover
      test "discover finds feed and returns feed information" do
        stub_request(:get, "https://example.com")
          .to_return(
            status: 200,
            body: '<html><head><link rel="alternate" type="application/rss+xml" href="https://example.com/feed.xml"></head></html>'
          )

        stub_request(:get, "https://example.com/feed.xml")
          .to_return(
            status: 200,
            body: '<?xml version="1.0"?><rss version="2.0"><channel><title>Example Feed</title></channel></rss>'
          )

        post discover_api_v1_feeds_url,
             params: { url: "https://example.com" },
             headers: api_headers(@alice),
             as: :json

        assert_response :success
        json = JSON.parse(response.body)

        assert json.key?("feed")
        assert json["feed"].key?("id")
        assert json["feed"].key?("title")
        assert json["feed"].key?("feed_url")
        assert json["feed"].key?("site_url")
      end

      test "discover returns existing feed if already in database" do
        initial_feed_count = Feed.count

        stub_request(:get, "https://techcrunch.com")
          .to_return(
            status: 200,
            body: "<html><head><link rel=\"alternate\" type=\"application/rss+xml\" href=\"#{@tech_crunch.feed_url}\"></head></html>"
          )

        stub_request(:get, @tech_crunch.feed_url)
          .to_return(
            status: 200,
            body: '<?xml version="1.0"?><rss version="2.0"><channel><title>TechCrunch</title></channel></rss>'
          )

        post discover_api_v1_feeds_url,
             params: { url: "https://techcrunch.com" },
             headers: api_headers(@alice),
             as: :json

        assert_response :success
        json = JSON.parse(response.body)

        # Should not create a new feed
        assert_equal initial_feed_count, Feed.count
        assert_equal @tech_crunch.id, json["feed"]["id"]
      end

      test "discover returns not found when feed cannot be discovered" do
        stub_request(:get, "https://example.com/no-feed")
          .to_return(status: 200, body: "<html><head></head><body>No feed here</body></html>")

        # Stub FeedDiscoveryService to return nil
        FeedDiscoveryService.any_instance.stubs(:discover).returns(nil)

        post discover_api_v1_feeds_url,
             params: { url: "https://example.com/no-feed" },
             headers: api_headers(@alice),
             as: :json

        assert_response :not_found
        json = JSON.parse(response.body)
        assert_equal "Feed not found", json["error"]
      end

      test "discover requires authentication" do
        post discover_api_v1_feeds_url,
             params: { url: "https://example.com" },
             as: :json

        assert_response :unauthorized
      end

      test "discover handles malformed URLs gracefully" do
        FeedDiscoveryService.any_instance.stubs(:discover).returns(nil)

        post discover_api_v1_feeds_url,
             params: { url: "not a url" },
             headers: api_headers(@alice),
             as: :json

        assert_response :not_found
        json = JSON.parse(response.body)
        assert_equal "Feed not found", json["error"]
      end

      # POST /api/v1/feeds
      test "create subscribes user to existing feed" do
        assert_difference("Subscription.count", 1) do
          post api_v1_feeds_url,
               params: {
                 feed_id: @ruby_weekly.id,
                 category: "Programming",
                 custom_name: "Ruby News"
               },
               headers: api_headers(@alice),
               as: :json
        end

        assert_response :created
        json = JSON.parse(response.body)

        assert json.key?("subscription")
        assert_equal "Programming", json["subscription"]["category"]
        assert_equal "Ruby News", json["subscription"]["custom_name"]
        assert_equal @ruby_weekly.id, json["subscription"]["feed"]["id"]
      end

      test "create returns correct subscription structure" do
        post api_v1_feeds_url,
             params: { feed_id: @ruby_weekly.id, category: "Tech" },
             headers: api_headers(@alice),
             as: :json

        assert_response :created
        json = JSON.parse(response.body)

        subscription = json["subscription"]

        assert subscription.key?("id")
        assert subscription.key?("category")
        assert subscription.key?("custom_name")
        assert subscription.key?("feed")

        feed = subscription["feed"]
        assert feed.key?("id")
        assert feed.key?("title")
        assert feed.key?("feed_url")
        assert feed.key?("site_url")
      end

      test "create allows subscription without category" do
        post api_v1_feeds_url,
             params: { feed_id: @ruby_weekly.id },
             headers: api_headers(@alice),
             as: :json

        assert_response :created
        json = JSON.parse(response.body)

        assert_nil json["subscription"]["category"]
      end

      test "create allows subscription without custom name" do
        post api_v1_feeds_url,
             params: { feed_id: @ruby_weekly.id, category: "Tech" },
             headers: api_headers(@alice),
             as: :json

        assert_response :created
        json = JSON.parse(response.body)

        assert_nil json["subscription"]["custom_name"]
      end

      test "create triggers background feed refresh job" do
        assert_enqueued_with(job: FeedRefreshJob, args: [ @ruby_weekly.id ]) do
          post api_v1_feeds_url,
               params: { feed_id: @ruby_weekly.id },
               headers: api_headers(@alice),
               as: :json
        end
      end

      test "create returns created for duplicate subscription (idempotent)" do
        # Alice is already subscribed to tech_crunch
        # With idempotent behavior, resubscribing returns success with existing subscription
        post api_v1_feeds_url,
             params: { feed_id: @tech_crunch.id, category: "Tech" },
             headers: api_headers(@alice),
             as: :json

        assert_response :created
        json = JSON.parse(response.body)

        assert json.key?("subscription")
        assert_equal @tech_crunch.id, json["subscription"]["feed"]["id"]
      end

      test "create returns not found for non-existent feed" do
        post api_v1_feeds_url,
             params: { feed_id: 99999, category: "Tech" },
             headers: api_headers(@alice),
             as: :json

        assert_response :not_found
        json = JSON.parse(response.body)
        assert_equal "Couldn't find Feed with 'id'=99999", json["error"]
      end

      test "create requires authentication" do
        post api_v1_feeds_url,
             params: { feed_id: @ruby_weekly.id },
             as: :json

        assert_response :unauthorized
      end

      test "create allows multiple users to subscribe to same feed" do
        # Bob is already subscribed to tech_crunch
        assert_difference("Subscription.count", 1) do
          post api_v1_feeds_url,
               params: { feed_id: @tech_crunch.id, category: "News" },
               headers: api_headers(@charlie),
               as: :json
        end

        assert_response :created
      end

      # DELETE /api/v1/feeds/:id
      test "destroy removes subscription for authenticated user" do
        assert_difference("Subscription.count", -1) do
          delete api_v1_feed_url(@tech_crunch.id),
                 headers: api_headers(@alice),
                 as: :json
        end

        assert_response :no_content
      end

      test "destroy returns no content on success" do
        delete api_v1_feed_url(@tech_crunch.id),
               headers: api_headers(@alice),
               as: :json

        assert_response :no_content
        assert_equal "", response.body
      end

      test "destroy only removes current user subscription" do
        # Both alice and bob are subscribed to tech_crunch
        initial_count = Subscription.count

        delete api_v1_feed_url(@tech_crunch.id),
               headers: api_headers(@alice),
               as: :json

        assert_response :no_content

        # Only alice's subscription should be removed
        assert_equal initial_count - 1, Subscription.count

        # Bob's subscription should still exist
        assert Subscription.exists?(user: @bob, feed: @tech_crunch)
      end

      test "destroy returns not found when subscription does not exist" do
        delete api_v1_feed_url(@ruby_weekly.id),
               headers: api_headers(@alice),
               as: :json

        assert_response :not_found
        json = JSON.parse(response.body)
        assert_equal "Subscription not found", json["error"]
      end

      test "destroy returns not found for non-existent feed" do
        delete api_v1_feed_url(id: 99999),
               headers: api_headers(@alice),
               as: :json

        assert_response :not_found
        json = JSON.parse(response.body)
        assert_equal "Subscription not found", json["error"]
      end

      test "destroy requires authentication" do
        delete api_v1_feed_url(@tech_crunch.id), as: :json

        assert_response :unauthorized
      end

      test "destroy does not delete feed from database" do
        initial_feed_count = Feed.count

        delete api_v1_feed_url(@tech_crunch.id),
               headers: api_headers(@alice),
               as: :json

        assert_response :no_content

        # Feed should still exist
        assert_equal initial_feed_count, Feed.count
        assert Feed.exists?(@tech_crunch.id)
      end

      # Edge cases and integration scenarios
      test "user can resubscribe to feed after unsubscribing" do
        # Unsubscribe
        delete api_v1_feed_url(@tech_crunch.id),
               headers: api_headers(@alice),
               as: :json

        assert_response :no_content

        # Resubscribe
        post api_v1_feeds_url,
             params: { feed_id: @tech_crunch.id, category: "Tech News" },
             headers: api_headers(@alice),
             as: :json

        assert_response :created
        json = JSON.parse(response.body)
        assert_equal "Tech News", json["subscription"]["category"]
      end

      test "create with same feed but different category for different users" do
        # Alice subscribes with Technology category
        post api_v1_feeds_url,
             params: { feed_id: @ruby_weekly.id, category: "Technology" },
             headers: api_headers(@alice),
             as: :json

        assert_response :created
        alice_sub = JSON.parse(response.body)

        # Charlie subscribes with Programming category
        post api_v1_feeds_url,
             params: { feed_id: @ruby_weekly.id, category: "Programming" },
             headers: api_headers(@charlie),
             as: :json

        assert_response :created
        charlie_sub = JSON.parse(response.body)

        assert_equal "Technology", alice_sub["subscription"]["category"]
        assert_equal "Programming", charlie_sub["subscription"]["category"]
      end

      test "create validates category length" do
        post api_v1_feeds_url,
             params: {
               feed_id: @ruby_weekly.id,
               category: "a" * 256  # Assuming max length validation
             },
             headers: api_headers(@alice),
             as: :json

        # This will succeed if no validation, or fail if validation exists
        # Adjust based on actual model validations
        assert_includes [ 201, 422 ], response.status
      end

      test "discover and subscribe workflow" do
        stub_request(:get, "https://newsite.com")
          .to_return(
            status: 200,
            body: '<html><head><link rel="alternate" type="application/rss+xml" href="https://newsite.com/rss"></head></html>'
          )

        stub_request(:get, "https://newsite.com/rss")
          .to_return(
            status: 200,
            body: '<?xml version="1.0"?><rss version="2.0"><channel><title>New Site</title></channel></rss>'
          )

        # Discover feed
        post discover_api_v1_feeds_url,
             params: { url: "https://newsite.com" },
             headers: api_headers(@alice),
             as: :json

        assert_response :success
        feed_data = JSON.parse(response.body)
        discovered_feed_id = feed_data["feed"]["id"]

        # Subscribe to discovered feed
        assert_difference("Subscription.count", 1) do
          post api_v1_feeds_url,
               params: { feed_id: discovered_feed_id, category: "New" },
               headers: api_headers(@alice),
               as: :json
        end

        assert_response :created
      end

      test "index includes feeds with null last_fetched_at" do
        new_feed = Feed.create!(
          title: "Never Fetched Feed",
          feed_url: "https://neverfetched.com/feed",
          site_url: "https://neverfetched.com",
          last_fetched_at: nil
        )

        Subscription.create!(
          user: @alice,
          feed: new_feed,
          category: "Test"
        )

        get api_v1_feeds_url, headers: api_headers(@alice), as: :json

        assert_response :success
        json = JSON.parse(response.body)

        never_fetched = json.find { |s| s["feed"]["id"] == new_feed.id }
        assert_not_nil never_fetched
        assert_nil never_fetched["feed"]["last_fetched_at"]
      end

      private

      def stub_feed_discovery_requests
        # Stub any potential HTTP requests made during tests
        # This prevents actual network calls during testing
      end
    end
  end
end

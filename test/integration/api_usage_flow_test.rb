require "test_helper"

class ApiUsageFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:alice)
    @api_token = @user.api_token
  end

  test "complete API registration flow" do
    # Register new user via API
    post api_v1_auth_register_path, params: {
      email: "apiuser@example.com",
      password: "apipassword123",
      password_confirmation: "apipassword123"
    }, as: :json

    assert_response :created
    json_response = JSON.parse(response.body)

    # Should return user data with API token
    assert json_response["user"].present?
    assert_equal "apiuser@example.com", json_response["user"]["email"]
    assert json_response["user"]["api_token"].present?
    assert json_response["user"]["id"].present?

    # Verify user was created
    user = User.find_by(email_address: "apiuser@example.com")
    assert user
    assert user.api_token.present?
  end

  test "API registration with invalid data returns errors" do
    post api_v1_auth_register_path, params: {
      email: "invalid@example.com",
      password: "pass",
      password_confirmation: "different"
    }, as: :json

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)

    assert json_response["error"].present?
  end

  test "complete API login flow" do
    # Login via API
    post api_v1_auth_login_path, params: {
      email: @user.email_address,
      password: "password"
    }, as: :json

    assert_response :ok
    json_response = JSON.parse(response.body)

    # Should return user data with API token
    assert_equal @user.id, json_response["user"]["id"]
    assert_equal @user.email_address, json_response["user"]["email"]
    # Reload user to get the newly issued token
    assert_equal @user.reload.api_token, json_response["user"]["api_token"]
  end

  test "API login with invalid credentials returns error" do
    post api_v1_auth_login_path, params: {
      email: @user.email_address,
      password: "wrongpassword"
    }, as: :json

    assert_response :unauthorized
    json_response = JSON.parse(response.body)

    assert_equal "Invalid email or password", json_response["error"]
  end

  test "fetch feeds via API with authentication" do
    get api_v1_feeds_path, headers: api_headers(@user), as: :json

    assert_response :ok
    json_response = JSON.parse(response.body)

    # Should return array of subscriptions
    assert json_response.is_a?(Array)
    assert json_response.length == 2  # Alice has 2 subscriptions

    # Check first subscription structure
    first_sub = json_response.first
    assert first_sub["id"].present?
    assert first_sub["category"].present?
    assert first_sub["feed"].present?
    assert first_sub["feed"]["title"].present?
    assert first_sub["feed"]["feed_url"].present?
  end

  test "API endpoints require authentication" do
    # Try to fetch feeds without authentication
    get api_v1_feeds_path, as: :json

    assert_response :unauthorized
  end

  test "discover feed via API" do
    feed_xml = <<~XML
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>API Discovery Feed</title>
          <link>https://apifeed.com</link>
        </channel>
      </rss>
    XML

    stub_request(:get, "https://apifeed.com/feed")
      .to_return(status: 200, body: feed_xml, headers: { "Content-Type" => "application/rss+xml" })

    post discover_api_v1_feeds_path,
         params: { url: "https://apifeed.com/feed" },
         headers: api_headers(@user),
         as: :json

    assert_response :ok
    json_response = JSON.parse(response.body)

    assert json_response["feed"].present?
    assert_equal "API Discovery Feed", json_response["feed"]["title"]
    assert_equal "https://apifeed.com/feed", json_response["feed"]["feed_url"]
  end

  test "subscribe to feed via API" do
    feed = feeds(:ruby_weekly)

    # Alice doesn't have this subscription yet
    assert_not @user.subscriptions.exists?(feed: feed)

    FeedRefreshJob.stubs(:perform_later)

    post api_v1_feeds_path,
         params: {
           feed_id: feed.id,
           category: "Programming",
           custom_name: "Ruby News"
         },
         headers: api_headers(@user),
         as: :json

    assert_response :created
    json_response = JSON.parse(response.body)

    # Should return subscription data
    assert json_response["subscription"].present?
    assert_equal "Programming", json_response["subscription"]["category"]
    assert_equal "Ruby News", json_response["subscription"]["custom_name"]
    assert_equal feed.id, json_response["subscription"]["feed"]["id"]

    # Verify subscription was created
    subscription = @user.subscriptions.find_by(feed: feed)
    assert subscription
    assert_equal "Programming", subscription.category
  end

  test "unsubscribe from feed via API" do
    feed = feeds(:tech_crunch)

    # Alice has this subscription
    assert @user.subscriptions.exists?(feed: feed)

    delete api_v1_feed_path(feed.id),
           headers: api_headers(@user),
           as: :json

    assert_response :no_content

    # Verify subscription was deleted
    assert_not @user.subscriptions.exists?(feed: feed)
  end

  test "fetch articles via API" do
    get api_v1_articles_path,
        headers: api_headers(@user),
        as: :json

    assert_response :ok
    json_response = JSON.parse(response.body)

    # Should return articles with metadata
    assert json_response["articles"].is_a?(Array)
    assert json_response["meta"].present?
    assert json_response["meta"]["total"].present?
    assert json_response["meta"]["limit"].present?

    # Check article structure
    first_article = json_response["articles"].first
    assert first_article["id"].present?
    assert first_article["title"].present?
    assert first_article["content"].present?
    assert first_article["url"].present?
    assert first_article["feed"].present?
    assert first_article["state"].present?
    assert first_article["state"].key?("read")
    assert first_article["state"].key?("starred")
    assert first_article["state"].key?("archived")
  end

  test "filter articles via API" do
    # Filter by unread
    get api_v1_articles_path,
        params: { filter: "unread" },
        headers: api_headers(@user),
        as: :json

    assert_response :ok
    json_response = JSON.parse(response.body)
    assert json_response["articles"].is_a?(Array)

    # Filter by starred
    get api_v1_articles_path,
        params: { filter: "starred" },
        headers: api_headers(@user),
        as: :json

    assert_response :ok
    json_response = JSON.parse(response.body)
    assert json_response["articles"].is_a?(Array)
  end

  test "fetch single article via API" do
    article = articles(:tc_article_1)

    get api_v1_article_path(article.id),
        headers: api_headers(@user),
        as: :json

    assert_response :ok
    json_response = JSON.parse(response.body)

    # Should return article details
    assert json_response["article"].present?
    assert_equal article.id, json_response["article"]["id"]
    assert_equal article.title, json_response["article"]["title"]
    assert json_response["article"]["state"].present?
  end

  test "mark article as read via API" do
    article = articles(:tc_article_1)
    state = article_states(:alice_tc_1)

    # Article is currently unread
    assert_not state.read

    patch mark_read_api_v1_article_path(article.id),
          params: { read: true },
          headers: api_headers(@user),
          as: :json

    assert_response :ok
    json_response = JSON.parse(response.body)

    assert json_response["state"]["read"] == true

    # Verify state changed
    state.reload
    assert state.read
  end

  test "mark article as starred via API" do
    article = articles(:tc_article_2)

    patch mark_starred_api_v1_article_path(article.id),
          params: { starred: true },
          headers: api_headers(@user),
          as: :json

    assert_response :ok
    json_response = JSON.parse(response.body)

    assert json_response["state"]["starred"] == true

    # Verify state changed
    state = article.state_for(@user)
    assert state.starred
  end

  test "mark article as archived via API" do
    article = articles(:tc_article_1)

    patch mark_archived_api_v1_article_path(article.id),
          params: { archived: true },
          headers: api_headers(@user),
          as: :json

    assert_response :ok
    json_response = JSON.parse(response.body)

    assert json_response["state"]["archived"] == true

    # Verify state changed
    state = article.state_for(@user)
    assert state.archived
  end

  test "search articles via API" do
    get search_api_v1_articles_path,
        params: { q: "AI" },
        headers: api_headers(@user),
        as: :json

    assert_response :ok
    json_response = JSON.parse(response.body)

    assert json_response["articles"].is_a?(Array)
    # Should find article with "AI" in title
    assert json_response["articles"].any? { |a| a["title"].include?("AI") }
  end

  test "API pagination works correctly" do
    get api_v1_articles_path,
        params: { limit: 10, offset: 0 },
        headers: api_headers(@user),
        as: :json

    assert_response :ok
    json_response = JSON.parse(response.body)

    assert_equal 10, json_response["meta"]["limit"]
    assert_equal 0, json_response["meta"]["offset"]
  end

  test "complete API workflow: login, discover, subscribe, read articles" do
    # Step 1: Login via API
    post api_v1_auth_login_path, params: {
      email: @user.email_address,
      password: "password"
    }, as: :json

    assert_response :ok
    login_response = JSON.parse(response.body)
    api_token = login_response["user"]["api_token"]

    # Step 2: Discover a feed
    feed_xml = <<~XML
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>Complete Flow Feed</title>
          <link>https://completeflow.com</link>
        </channel>
      </rss>
    XML

    stub_request(:get, "https://completeflow.com/feed")
      .to_return(status: 200, body: feed_xml, headers: { "Content-Type" => "application/rss+xml" })

    post discover_api_v1_feeds_path,
         params: { url: "https://completeflow.com/feed" },
         headers: { "Authorization" => "Bearer #{api_token}" },
         as: :json

    assert_response :ok
    discovery_response = JSON.parse(response.body)
    feed_id = discovery_response["feed"]["id"]

    # Step 3: Subscribe to the feed
    FeedRefreshJob.stubs(:perform_later)

    post api_v1_feeds_path,
         params: { feed_id: feed_id, category: "Testing" },
         headers: { "Authorization" => "Bearer #{api_token}" },
         as: :json

    assert_response :created

    # Step 4: Fetch articles
    get api_v1_articles_path,
        headers: { "Authorization" => "Bearer #{api_token}" },
        as: :json

    assert_response :ok
    articles_response = JSON.parse(response.body)
    assert articles_response["articles"].is_a?(Array)

    # Step 5: Mark an article as read
    article_id = articles(:tc_article_1).id

    patch mark_read_api_v1_article_path(article_id),
          params: { read: true },
          headers: { "Authorization" => "Bearer #{api_token}" },
          as: :json

    assert_response :ok
  end

  test "invalid API token returns unauthorized" do
    get api_v1_feeds_path,
        headers: { "Authorization" => "Bearer invalid_token_123" },
        as: :json

    assert_response :unauthorized
  end

  test "missing API token returns unauthorized" do
    get api_v1_feeds_path, as: :json

    assert_response :unauthorized
  end

  test "API returns JSON format" do
    get api_v1_articles_path,
        headers: api_headers(@user),
        as: :json

    assert_response :ok
    assert_equal "application/json", response.media_type
  end

  test "different users get different data via API" do
    bob = users(:bob)

    # Fetch Alice's articles
    get api_v1_articles_path,
        headers: api_headers(@user),
        as: :json

    alice_articles = JSON.parse(response.body)["articles"]

    # Fetch Bob's articles
    get api_v1_articles_path,
        headers: api_headers(bob),
        as: :json

    bob_articles = JSON.parse(response.body)["articles"]

    # Articles should be different based on subscriptions
    alice_article_ids = alice_articles.map { |a| a["id"] }.sort
    bob_article_ids = bob_articles.map { |a| a["id"] }.sort

    assert_not_equal alice_article_ids, bob_article_ids
  end

  test "API discovery handles feed not found" do
    stub_request(:get, "https://notfound.com")
      .to_return(status: 404)

    post discover_api_v1_feeds_path,
         params: { url: "https://notfound.com" },
         headers: api_headers(@user),
         as: :json

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "Feed not found", json_response["error"]
  end

  test "API subscribe with duplicate feed returns error" do
    feed = feeds(:tech_crunch)

    # Alice already has this subscription
    post api_v1_feeds_path,
         params: { feed_id: feed.id, category: "Tech" },
         headers: api_headers(@user),
         as: :json

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response["error"].present?
  end

  test "API unsubscribe non-existent subscription returns not found" do
    feed = feeds(:ruby_weekly)

    # Alice doesn't have this subscription
    assert_not @user.subscriptions.exists?(feed: feed)

    delete api_v1_feed_path(feed.id),
           headers: api_headers(@user),
           as: :json

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "Subscription not found", json_response["error"]
  end

  test "complete new user API journey: register, discover, subscribe, manage articles" do
    # Step 1: Register new user
    post api_v1_auth_register_path, params: {
      email: "journey@example.com",
      password: "journey123",
      password_confirmation: "journey123"
    }, as: :json

    assert_response :created
    user_data = JSON.parse(response.body)["user"]
    token = user_data["api_token"]
    headers = { "Authorization" => "Bearer #{token}" }

    # Step 2: Discover and subscribe to a feed
    feed_xml = <<~XML
      <?xml version="1.0"?>
      <rss version="2.0">
        <channel>
          <title>Journey Feed</title>
        </channel>
      </rss>
    XML

    stub_request(:get, "https://journey.com/feed")
      .to_return(status: 200, body: feed_xml, headers: { "Content-Type" => "application/rss+xml" })

    post discover_api_v1_feeds_path,
         params: { url: "https://journey.com/feed" },
         headers: headers,
         as: :json

    assert_response :ok, "Discovery failed with response: #{response.body}"
    feed_data = JSON.parse(response.body)
    assert feed_data["feed"].present?, "No feed returned in discovery response"
    feed_id = feed_data["feed"]["id"]

    FeedRefreshJob.stubs(:perform_later)

    post api_v1_feeds_path,
         params: { feed_id: feed_id, category: "Personal" },
         headers: headers,
         as: :json

    assert_response :created

    # Step 3: Check subscriptions
    get api_v1_feeds_path, headers: headers, as: :json
    assert_response :ok
    feeds = JSON.parse(response.body)
    assert_equal 1, feeds.length

    # Step 4: Fetch articles
    get api_v1_articles_path, headers: headers, as: :json
    assert_response :ok
  end

  test "API filter by feed_id" do
    feed = feeds(:tech_crunch)

    get api_v1_articles_path,
        params: { feed_id: feed.id },
        headers: api_headers(@user),
        as: :json

    assert_response :ok
    json_response = JSON.parse(response.body)

    # All articles should be from the specified feed
    json_response["articles"].each do |article|
      assert_equal feed.id, article["feed"]["id"]
    end
  end

  test "API filter by category" do
    get api_v1_articles_path,
        params: { category: "Technology" },
        headers: api_headers(@user),
        as: :json

    assert_response :ok
    json_response = JSON.parse(response.body)

    # Should only return articles from feeds in Technology category
    assert json_response["articles"].is_a?(Array)
  end

  test "API article state management workflow" do
    article = articles(:tc_article_1)
    headers = api_headers(@user)

    # Mark as read
    patch mark_read_api_v1_article_path(article.id),
          params: { read: true },
          headers: headers,
          as: :json
    assert_response :ok

    # Star the article
    patch mark_starred_api_v1_article_path(article.id),
          params: { starred: true },
          headers: headers,
          as: :json
    assert_response :ok

    # Fetch the article to verify states
    get api_v1_article_path(article.id),
        headers: headers,
        as: :json

    article_data = JSON.parse(response.body)["article"]
    assert article_data["state"]["read"]
    assert article_data["state"]["starred"]

    # Archive it
    patch mark_archived_api_v1_article_path(article.id),
          params: { archived: true },
          headers: headers,
          as: :json
    assert_response :ok

    # Fetch again
    get api_v1_article_path(article.id),
        headers: headers,
        as: :json

    article_data = JSON.parse(response.body)["article"]
    assert article_data["state"]["archived"]
  end
end

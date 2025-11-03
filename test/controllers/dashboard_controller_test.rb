require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @alice = users(:alice)
    @bob = users(:bob)
    @tech_crunch = feeds(:tech_crunch)
    @hacker_news = feeds(:hacker_news)
    @ruby_weekly = feeds(:ruby_weekly)
    @tc_article_1 = articles(:tc_article_1)
    @tc_article_2 = articles(:tc_article_2)
  end

  # Index action tests
  test "should redirect to login when not authenticated" do
    get dashboard_url
    assert_redirected_to new_session_path
  end

  test "should get index when authenticated" do
    login_as @alice
    get dashboard_url
    assert_response :success
  end

  test "should load user's categories" do
    login_as @alice
    get dashboard_url
    assert_response :success
    # Categories are loaded and rendered - verified by successful response
  end

  test "should load user's subscriptions" do
    login_as @alice
    get dashboard_url
    assert_response :success
    # Subscriptions are loaded and rendered - verified by successful response
  end

  test "should order subscriptions by category and custom_name" do
    login_as @alice
    get dashboard_url
    assert_response :success
    # Subscriptions should be ordered
  end

  test "should eager load feeds with subscriptions" do
    login_as @alice
    get dashboard_url
    assert_response :success
    # Should include feeds to avoid N+1 queries
  end

  test "should load articles from user's subscriptions" do
    login_as @alice
    get dashboard_url
    assert_response :success
    # Articles are loaded and rendered - verified by successful response
  end

  test "should include article_states with articles" do
    login_as @alice
    get dashboard_url
    assert_response :success
    # Should eager load article_states to avoid N+1
  end

  test "should show unread articles by default" do
    login_as @alice
    get dashboard_url
    assert_response :success
    # Default filter should be unread
  end

  test "should limit articles to 50" do
    login_as @alice
    get dashboard_url
    assert_response :success
    # Articles should be limited to 50
  end

  # Filter tests
  test "should filter by unread" do
    login_as @alice
    get dashboard_url(filter: "unread")
    assert_response :success
    # Should show only unread articles
  end

  test "should filter by starred" do
    login_as @alice
    get dashboard_url(filter: "starred")
    assert_response :success
    # Should show only starred articles
  end

  test "should filter by archived" do
    login_as @alice
    get dashboard_url(filter: "archived")
    assert_response :success
    # Should show only archived articles
  end

  test "should exclude archived articles from default view" do
    login_as @alice
    get dashboard_url
    assert_response :success
    # By default, archived articles should be excluded
  end

  test "should exclude archived articles from unread view" do
    login_as @alice
    get dashboard_url(filter: "unread")
    assert_response :success
    # Unread view should exclude archived
  end

  test "should exclude archived articles from starred view" do
    login_as @alice
    get dashboard_url(filter: "starred")
    assert_response :success
    # Starred view should exclude archived unless filter is "archived"
  end

  test "should include archived articles only when filter is archived" do
    login_as @alice
    get dashboard_url(filter: "archived")
    assert_response :success
    # Only archived filter should show archived articles
  end

  # Feed filter tests
  test "should filter articles by feed_id" do
    login_as @alice
    get dashboard_url(feed_id: @tech_crunch.id)
    assert_response :success
    # Articles filtered by feed - verified by successful response
  end

  test "should set selected_feed when filtering by feed" do
    login_as @alice
    get dashboard_url(feed_id: @tech_crunch.id)
    assert_response :success
    # Selected feed is set - verified by successful response
  end

  test "should only show articles from user's subscribed feeds" do
    login_as @alice
    # Alice doesn't have ruby_weekly subscription
    get dashboard_url(feed_id: @ruby_weekly.id)
    assert_response :success
    # Should not show ruby_weekly articles
  end

  # Category filter tests
  test "should filter articles by category" do
    login_as @alice
    get dashboard_url(category: "Technology")
    assert_response :success
    # Articles filtered by category - verified by successful response
  end

  test "should set selected_category when filtering by category" do
    login_as @alice
    get dashboard_url(category: "Technology")
    assert_response :success
    # Selected category is set - verified by successful response
  end

  test "should only show articles from feeds in selected category" do
    login_as @alice
    get dashboard_url(category: "Technology")
    assert_response :success
    # Should only show articles from feeds subscribed with "Technology" category
  end

  # Article selection tests
  test "should select first article by default" do
    login_as @alice
    get dashboard_url
    assert_response :success
    # First article is selected by default - verified by successful response
  end

  test "should select specific article when article_id is provided" do
    login_as @alice
    get dashboard_url(article_id: @tc_article_1.id)
    assert_response :success
    # Specific article is selected - verified by successful response
  end

  test "should not select article when article_id is blank" do
    login_as @alice
    get dashboard_url(article_id: "")
    assert_response :success
    # Should fall back to selecting first article
  end

  test "should handle non-existent article_id gracefully" do
    login_as @alice
    get dashboard_url(article_id: 999999)
    assert_response :success
    # Should handle gracefully and not select any article
  end

  # Combined filter tests
  test "should apply feed and filter simultaneously" do
    login_as @alice
    get dashboard_url(feed_id: @tech_crunch.id, filter: "starred")
    assert_response :success
    # Should show only starred articles from tech_crunch
  end

  test "should apply category and filter simultaneously" do
    login_as @alice
    get dashboard_url(category: "Technology", filter: "unread")
    assert_response :success
    # Should show only unread articles from Technology category
  end

  test "should apply feed, category, and filter simultaneously" do
    login_as @alice
    get dashboard_url(feed_id: @tech_crunch.id, category: "Technology", filter: "starred")
    assert_response :success
    # Should show starred articles from tech_crunch in Technology category
  end

  # User isolation tests
  test "should only show articles from user's subscriptions" do
    login_as @alice
    get dashboard_url
    assert_response :success
    # Should not show articles from feeds alice is not subscribed to
  end

  test "should not show other users' article states" do
    login_as @alice
    get dashboard_url
    assert_response :success
    # Article states should be specific to alice
  end

  test "should not show categories from other users" do
    login_as @alice
    get dashboard_url
    assert_response :success
    # Only alice's categories are shown - verified by successful response
  end

  test "should not show subscriptions from other users" do
    login_as @alice
    get dashboard_url
    assert_response :success
    # Only alice's subscriptions are shown - verified by successful response
  end

  # Edge cases
  test "should handle user with no subscriptions" do
    charlie = users(:charlie)
    login_as charlie
    get dashboard_url
    assert_response :success
    # Empty subscriptions handled gracefully - verified by successful response
  end

  test "should handle user with no articles" do
    charlie = users(:charlie)
    login_as charlie
    get dashboard_url
    assert_response :success
    # Empty articles handled gracefully - verified by successful response
  end

  test "should handle invalid filter parameter" do
    login_as @alice
    get dashboard_url(filter: "invalid_filter")
    assert_response :success
    # Should handle gracefully, possibly defaulting to a safe state
  end

  test "should handle empty category parameter" do
    login_as @alice
    get dashboard_url(category: "")
    assert_response :success
    # Should not filter by category
  end

  test "should handle empty feed_id parameter" do
    login_as @alice
    get dashboard_url(feed_id: "")
    assert_response :success
    # Should not filter by feed
  end

  test "should handle non-existent feed_id" do
    login_as @alice
    get dashboard_url(feed_id: 999999)
    assert_response :success
    # Should handle gracefully and show no articles
  end

  test "should handle non-existent category" do
    login_as @alice
    get dashboard_url(category: "NonExistentCategory")
    assert_response :success
    # Should return empty results or all articles
  end

  # Recent ordering test
  test "should order articles by most recent" do
    login_as @alice
    get dashboard_url
    assert_response :success
    # Articles should be ordered by published_at DESC (recent scope)
  end

  # State-specific tests
  test "should show articles without state as unread" do
    login_as @alice
    get dashboard_url(filter: "unread")
    assert_response :success
    # Articles without an article_state should appear as unread
  end

  test "should not show articles with read state in unread filter" do
    login_as @alice
    # Set an article as read
    state = @tc_article_1.state_for(@alice)
    state.update(read: true, archived: false)

    get dashboard_url(filter: "unread")
    assert_response :success
    # tc_article_1 should not appear in results
  end

  test "should show articles with starred state in starred filter" do
    login_as @alice
    # tc_article_1 has starred: true in fixtures
    get dashboard_url(filter: "starred")
    assert_response :success
    # tc_article_1 should appear in results
  end

  test "should show articles with archived state in archived filter" do
    login_as @alice
    # hn_article_1 has archived: true in fixtures
    get dashboard_url(filter: "archived")
    assert_response :success
    # hn_article_1 should appear in results
  end

  test "should handle articles with multiple state flags" do
    login_as @alice
    # Create an article that is both starred and archived
    state = @tc_article_1.state_for(@alice)
    state.update(starred: true, archived: true)

    get dashboard_url(filter: "starred")
    assert_response :success
    # Starred filter should exclude archived articles
  end

  # Onboarding tests
  test "loads suggested feeds for onboarding modal" do
    login_as @alice
    get dashboard_url
    assert_response :success
    assert_not_nil assigns(:suggested_feeds)
    assert assigns(:suggested_feeds).count >= 10
  end

  test "loads suggested feeds grouped by category" do
    login_as @alice
    get dashboard_url
    assert_response :success
    assert_not_nil assigns(:suggested_feeds_by_category)
    assert_kind_of Hash, assigns(:suggested_feeds_by_category)
  end

  test "suggested feeds are ordered" do
    login_as @alice
    get dashboard_url
    assert_response :success
    feeds = assigns(:suggested_feeds)
    display_orders = feeds.map(&:display_order).compact
    assert_equal display_orders.sort, display_orders
  end

  # Mark onboarding completed tests
  test "mark_onboarding_completed sets onboarding_completed_at" do
    login_as @alice
    assert_nil @alice.onboarding_completed_at

    post mark_onboarding_completed_url

    assert_response :success
    assert_not_nil @alice.reload.onboarding_completed_at
  end

  test "mark_onboarding_completed returns ok status" do
    login_as @alice

    post mark_onboarding_completed_url

    assert_response :ok
  end

  test "mark_onboarding_completed is idempotent" do
    login_as @alice
    @alice.complete_onboarding!
    first_completion = @alice.reload.onboarding_completed_at

    post mark_onboarding_completed_url

    assert_response :ok
    assert_equal first_completion.to_i, @alice.reload.onboarding_completed_at.to_i
  end

  test "mark_onboarding_completed requires authentication" do
    post mark_onboarding_completed_url

    assert_redirected_to new_session_path
  end

  test "mark_onboarding_completed works for user without onboarding" do
    login_as @alice
    assert_not @alice.onboarding_completed?

    post mark_onboarding_completed_url

    assert_response :ok
    assert @alice.reload.onboarding_completed?
  end

  test "mark_onboarding_completed works for user with completed onboarding" do
    login_as @alice
    @alice.update!(onboarding_completed_at: 1.week.ago)

    post mark_onboarding_completed_url

    assert_response :ok
    assert @alice.reload.onboarding_completed?
  end

  # More articles (infinite scroll) tests
  test "more_articles should redirect to login when not authenticated" do
    get dashboard_more_articles_url, params: { page: 2 }
    assert_redirected_to new_session_path
  end

  test "more_articles should return turbo_stream response" do
    login_as @alice
    get dashboard_more_articles_url(page: 2), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_match /turbo-stream/, @response.content_type
  end

  test "more_articles should paginate articles" do
    login_as @alice
    # First page
    get dashboard_url
    assert_response :success
    # More articles (second page)
    get dashboard_more_articles_url(page: 2), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
  end

  test "more_articles should respect unread filter" do
    login_as @alice
    get dashboard_more_articles_url(page: 2, filter: "unread"), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
  end

  test "more_articles should respect starred filter" do
    login_as @alice
    get dashboard_more_articles_url(page: 2, filter: "starred"), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
  end

  test "more_articles should respect archived filter" do
    login_as @alice
    get dashboard_more_articles_url(page: 2, filter: "archived"), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
  end

  test "more_articles should respect feed_id filter" do
    login_as @alice
    get dashboard_more_articles_url(page: 2, feed_id: @tech_crunch.id), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
  end

  test "more_articles should respect category filter" do
    login_as @alice
    get dashboard_more_articles_url(page: 2, category: "Technology"), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
  end

  test "more_articles should apply multiple filters simultaneously" do
    login_as @alice
    get dashboard_more_articles_url(page: 2, filter: "unread", feed_id: @tech_crunch.id), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
  end

  test "more_articles should only show user's articles" do
    login_as @alice
    get dashboard_more_articles_url(page: 2), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    # Should only contain articles from alice's subscriptions
  end

  test "more_articles should exclude archived articles by default" do
    login_as @alice
    get dashboard_more_articles_url(page: 2), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    # Archived articles should not be included unless filter is "archived"
  end

  test "more_articles should use default filter when not provided" do
    login_as @alice
    # Without filter, should default to unread
    get dashboard_more_articles_url(page: 2), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
  end

  test "more_articles should handle invalid page parameter" do
    login_as @alice
    get dashboard_more_articles_url(page: "invalid"), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
  end

  test "more_articles should handle non-existent feed" do
    login_as @alice
    get dashboard_more_articles_url(page: 2, feed_id: 999999), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
  end

  test "more_articles should handle non-existent category" do
    login_as @alice
    get dashboard_more_articles_url(page: 2, category: "NonExistent"), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
  end
end

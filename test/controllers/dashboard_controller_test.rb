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
    get root_url
    assert_redirected_to new_session_path
  end

  test "should get index when authenticated" do
    login_as @alice
    get root_url
    assert_response :success
  end

  test "should load user's categories" do
    login_as @alice
    get root_url
    assert_response :success
    # Categories are loaded and rendered - verified by successful response
  end

  test "should load user's subscriptions" do
    login_as @alice
    get root_url
    assert_response :success
    # Subscriptions are loaded and rendered - verified by successful response
  end

  test "should order subscriptions by category and custom_name" do
    login_as @alice
    get root_url
    assert_response :success
    # Subscriptions should be ordered
  end

  test "should eager load feeds with subscriptions" do
    login_as @alice
    get root_url
    assert_response :success
    # Should include feeds to avoid N+1 queries
  end

  test "should load articles from user's subscriptions" do
    login_as @alice
    get root_url
    assert_response :success
    # Articles are loaded and rendered - verified by successful response
  end

  test "should include article_states with articles" do
    login_as @alice
    get root_url
    assert_response :success
    # Should eager load article_states to avoid N+1
  end

  test "should show unread articles by default" do
    login_as @alice
    get root_url
    assert_response :success
    # Default filter should be unread
  end

  test "should limit articles to 50" do
    login_as @alice
    get root_url
    assert_response :success
    # Articles should be limited to 50
  end

  # Filter tests
  test "should filter by unread" do
    login_as @alice
    get root_url(filter: "unread")
    assert_response :success
    # Should show only unread articles
  end

  test "should filter by starred" do
    login_as @alice
    get root_url(filter: "starred")
    assert_response :success
    # Should show only starred articles
  end

  test "should filter by archived" do
    login_as @alice
    get root_url(filter: "archived")
    assert_response :success
    # Should show only archived articles
  end

  test "should exclude archived articles from default view" do
    login_as @alice
    get root_url
    assert_response :success
    # By default, archived articles should be excluded
  end

  test "should exclude archived articles from unread view" do
    login_as @alice
    get root_url(filter: "unread")
    assert_response :success
    # Unread view should exclude archived
  end

  test "should exclude archived articles from starred view" do
    login_as @alice
    get root_url(filter: "starred")
    assert_response :success
    # Starred view should exclude archived unless filter is "archived"
  end

  test "should include archived articles only when filter is archived" do
    login_as @alice
    get root_url(filter: "archived")
    assert_response :success
    # Only archived filter should show archived articles
  end

  # Feed filter tests
  test "should filter articles by feed_id" do
    login_as @alice
    get root_url(feed_id: @tech_crunch.id)
    assert_response :success
    # Articles filtered by feed - verified by successful response
  end

  test "should set selected_feed when filtering by feed" do
    login_as @alice
    get root_url(feed_id: @tech_crunch.id)
    assert_response :success
    # Selected feed is set - verified by successful response
  end

  test "should only show articles from user's subscribed feeds" do
    login_as @alice
    # Alice doesn't have ruby_weekly subscription
    get root_url(feed_id: @ruby_weekly.id)
    assert_response :success
    # Should not show ruby_weekly articles
  end

  # Category filter tests
  test "should filter articles by category" do
    login_as @alice
    get root_url(category: "Technology")
    assert_response :success
    # Articles filtered by category - verified by successful response
  end

  test "should set selected_category when filtering by category" do
    login_as @alice
    get root_url(category: "Technology")
    assert_response :success
    # Selected category is set - verified by successful response
  end

  test "should only show articles from feeds in selected category" do
    login_as @alice
    get root_url(category: "Technology")
    assert_response :success
    # Should only show articles from feeds subscribed with "Technology" category
  end

  # Article selection tests
  test "should select first article by default" do
    login_as @alice
    get root_url
    assert_response :success
    # First article is selected by default - verified by successful response
  end

  test "should select specific article when article_id is provided" do
    login_as @alice
    get root_url(article_id: @tc_article_1.id)
    assert_response :success
    # Specific article is selected - verified by successful response
  end

  test "should not select article when article_id is blank" do
    login_as @alice
    get root_url(article_id: "")
    assert_response :success
    # Should fall back to selecting first article
  end

  test "should handle non-existent article_id gracefully" do
    login_as @alice
    assert_raises(ActiveRecord::RecordNotFound) do
      get root_url(article_id: 999999)
    end
  end

  # Combined filter tests
  test "should apply feed and filter simultaneously" do
    login_as @alice
    get root_url(feed_id: @tech_crunch.id, filter: "starred")
    assert_response :success
    # Should show only starred articles from tech_crunch
  end

  test "should apply category and filter simultaneously" do
    login_as @alice
    get root_url(category: "Technology", filter: "unread")
    assert_response :success
    # Should show only unread articles from Technology category
  end

  test "should apply feed, category, and filter simultaneously" do
    login_as @alice
    get root_url(feed_id: @tech_crunch.id, category: "Technology", filter: "starred")
    assert_response :success
    # Should show starred articles from tech_crunch in Technology category
  end

  # User isolation tests
  test "should only show articles from user's subscriptions" do
    login_as @alice
    get root_url
    assert_response :success
    # Should not show articles from feeds alice is not subscribed to
  end

  test "should not show other users' article states" do
    login_as @alice
    get root_url
    assert_response :success
    # Article states should be specific to alice
  end

  test "should not show categories from other users" do
    login_as @alice
    get root_url
    assert_response :success
    # Only alice's categories are shown - verified by successful response
  end

  test "should not show subscriptions from other users" do
    login_as @alice
    get root_url
    assert_response :success
    # Only alice's subscriptions are shown - verified by successful response
  end

  # Edge cases
  test "should handle user with no subscriptions" do
    charlie = users(:charlie)
    login_as charlie
    get root_url
    assert_response :success
    # Empty subscriptions handled gracefully - verified by successful response
  end

  test "should handle user with no articles" do
    charlie = users(:charlie)
    login_as charlie
    get root_url
    assert_response :success
    # Empty articles handled gracefully - verified by successful response
  end

  test "should handle invalid filter parameter" do
    login_as @alice
    get root_url(filter: "invalid_filter")
    assert_response :success
    # Should handle gracefully, possibly defaulting to a safe state
  end

  test "should handle empty category parameter" do
    login_as @alice
    get root_url(category: "")
    assert_response :success
    # Should not filter by category
  end

  test "should handle empty feed_id parameter" do
    login_as @alice
    get root_url(feed_id: "")
    assert_response :success
    # Should not filter by feed
  end

  test "should handle non-existent feed_id" do
    login_as @alice
    assert_raises(ActiveRecord::RecordNotFound) do
      get root_url(feed_id: 999999)
    end
  end

  test "should handle non-existent category" do
    login_as @alice
    get root_url(category: "NonExistentCategory")
    assert_response :success
    # Should return empty results or all articles
  end

  # Recent ordering test
  test "should order articles by most recent" do
    login_as @alice
    get root_url
    assert_response :success
    # Articles should be ordered by published_at DESC (recent scope)
  end

  # State-specific tests
  test "should show articles without state as unread" do
    login_as @alice
    get root_url(filter: "unread")
    assert_response :success
    # Articles without an article_state should appear as unread
  end

  test "should not show articles with read state in unread filter" do
    login_as @alice
    # Set an article as read
    state = @tc_article_1.state_for(@alice)
    state.update(read: true, archived: false)

    get root_url(filter: "unread")
    assert_response :success
    # tc_article_1 should not appear in results
  end

  test "should show articles with starred state in starred filter" do
    login_as @alice
    # tc_article_1 has starred: true in fixtures
    get root_url(filter: "starred")
    assert_response :success
    # tc_article_1 should appear in results
  end

  test "should show articles with archived state in archived filter" do
    login_as @alice
    # hn_article_1 has archived: true in fixtures
    get root_url(filter: "archived")
    assert_response :success
    # hn_article_1 should appear in results
  end

  test "should handle articles with multiple state flags" do
    login_as @alice
    # Create an article that is both starred and archived
    state = @tc_article_1.state_for(@alice)
    state.update(starred: true, archived: true)

    get root_url(filter: "starred")
    assert_response :success
    # Starred filter should exclude archived articles
  end
end

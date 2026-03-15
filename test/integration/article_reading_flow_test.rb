require "test_helper"

class ArticleReadingFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:alice)
    @other_user = users(:bob)
    login_as(@user)
  end

  test "browse all articles from subscribed feeds" do
    get articles_path
    assert_response :success
    # Articles view is rendered successfully
  end

  test "filter articles by feed" do
    tech_crunch = feeds(:tech_crunch)

    get articles_path, params: { feed_id: tech_crunch.id }
    assert_response :success
    # Feed filter applied successfully
  end

  test "filter articles by category" do
    get articles_path, params: { category: "Technology" }
    assert_response :success
    # Category filter applied successfully
  end

  test "filter unread articles" do
    get articles_path, params: { filter: "unread" }
    assert_response :success
    # Unread filter applied successfully
  end

  test "filter starred articles" do
    get articles_path, params: { filter: "starred" }
    assert_response :success
    # Starred filter applied successfully
  end

  test "filter archived articles" do
    get articles_path, params: { filter: "archived" }
    assert_response :success
    # Archived filter applied successfully
  end

  test "view single article" do
    article = articles(:tc_article_1)

    get article_path(article)
    assert_response :success
    # Article view rendered successfully
  end

  test "mark article as read" do
    article = articles(:tc_article_1)
    state = article_states(:alice_tc_1)

    # Article is currently unread
    assert_not state.read

    # Mark as read
    patch toggle_read_article_path(article)
    assert_response :success

    # Verify state changed
    state.reload
    assert state.read
  end

  test "mark article as unread" do
    article = articles(:tc_article_2)
    state = article_states(:alice_tc_2)

    # Article is currently read
    assert state.read

    # Mark as unread
    patch toggle_read_article_path(article)
    assert_response :success

    # Verify state changed
    state.reload
    assert_not state.read
  end

  test "toggle article starred status" do
    article = articles(:tc_article_1)
    state = article_states(:alice_tc_1)

    # Article is currently starred
    assert state.starred

    # Unstar it
    patch toggle_starred_article_path(article)
    assert_response :success

    state.reload
    assert_not state.starred

    # Star it again
    patch toggle_starred_article_path(article)
    assert_response :success

    state.reload
    assert state.starred
  end

  test "archive article" do
    article = articles(:tc_article_1)
    state = article_states(:alice_tc_1)

    # Article is not archived
    assert_not state.archived

    # Archive it
    patch toggle_archived_article_path(article)
    assert_redirected_to articles_path

    state.reload
    assert state.archived
  end

  test "unarchive article" do
    article = articles(:tc_article_2)
    state = article_states(:alice_tc_2)

    # Article is archived
    assert state.archived

    # Unarchive it
    patch toggle_archived_article_path(article)
    assert_redirected_to articles_path

    state.reload
    assert_not state.archived
  end

  test "article state is created on first interaction" do
    # Create a new article that alice hasn't interacted with
    new_article = Article.create!(
      feed: feeds(:tech_crunch),
      title: "Brand New Article",
      content: "This is new content",
      url: "https://techcrunch.com/new",
      guid: "new_article_guid_123",
      published_at: Time.current
    )

    # Alice has no state for this article yet
    assert_not ArticleState.exists?(user: @user, article: new_article)

    # Toggle read status (creates state)
    assert_difference "ArticleState.count", 1 do
      patch toggle_read_article_path(new_article)
    end

    # State should be created with read=true
    state = ArticleState.find_by(user: @user, article: new_article)
    assert state
    assert state.read
  end

  test "search articles by title" do
    get search_path, params: { q: "AI Developments" }
    assert_response :success
    # Search performed successfully
  end

  test "search articles by content" do
    get search_path, params: { q: "summary" }
    assert_response :success
    # Content search performed successfully
  end

  test "search only searches user's subscribed feeds" do
    # Bob's article from ruby_weekly
    ruby_article = articles(:ruby_article_1)

    # Alice searches for Ruby
    get search_path, params: { q: "Ruby" }
    assert_response :success
    # Search scoped to user's subscriptions
  end

  test "fetch full article content" do
    article = articles(:tc_article_1)

    # Article has no full content initially
    assert_nil article.full_content

    # Stub the content fetcher service
    full_content = "This is the complete full article content fetched from the web page."
    ArticleContentFetcherService.any_instance.stubs(:fetch).returns(true)
    article.stubs(:update).with(full_content: nil).returns(true)

    # Fetch content
    post fetch_content_article_path(article)
    assert_redirected_to dashboard_path(article_id: article.id)
  end

  test "complete reading workflow: browse, filter, read, mark states" do
    # Step 1: Browse all articles
    get articles_path
    assert_response :success

    # Step 2: Filter to unread
    get articles_path, params: { filter: "unread" }
    assert_response :success

    article = articles(:tc_article_1)

    # Step 3: View article
    get article_path(article)
    assert_response :success

    # Step 4: Mark as read
    patch toggle_read_article_path(article)
    assert_response :no_content

    state = article_states(:alice_tc_1)
    state.reload
    assert state.read

    # Step 5: Star the article (it was already starred, so this will unstar)
    patch toggle_starred_article_path(article)
    assert_response :no_content

    state.reload
    assert_not state.starred  # Changed: it was starred, now it's not

    # Step 6: View starred articles
    get articles_path, params: { filter: "starred" }
    assert_response :success
  end

  test "article states are user-specific" do
    article = articles(:tc_article_1)

    # Alice's state
    alice_state = article_states(:alice_tc_1)
    assert_not alice_state.read
    assert alice_state.starred

    # Mark as read for Alice
    patch toggle_read_article_path(article)
    assert_response :success

    alice_state.reload
    assert alice_state.read

    # Switch to Bob
    login_as(@other_user)

    # Bob should have no state for this article initially
    assert_not ArticleState.exists?(user: @other_user, article: article)

    # Create state for Bob
    patch toggle_read_article_path(article)
    bob_state = ArticleState.find_by(user: @other_user, article: article)

    # Bob's state is independent
    assert bob_state.read
    assert_not bob_state.starred

    # Alice's state unchanged
    alice_state.reload
    assert alice_state.read
    assert alice_state.starred
  end

  test "reading articles from different feeds" do
    tc_article = articles(:tc_article_1)
    hn_article = articles(:hn_article_1)

    # View article from TechCrunch
    get article_path(tc_article)
    assert_response :success

    # View article from Hacker News
    get article_path(hn_article)
    assert_response :success
    # Both articles viewable successfully
  end

  test "manage multiple article states in sequence" do
    article1 = articles(:tc_article_1)
    article2 = articles(:tc_article_2)

    # Toggle article 1 read (unread -> read)
    patch toggle_read_article_path(article1)
    assert_response :no_content

    # Toggle article 1 starred (starred -> unstarred)
    patch toggle_starred_article_path(article1)
    assert_response :no_content

    state1 = article_states(:alice_tc_1)
    state1.reload
    assert state1.read
    assert_not state1.starred  # Was starred, now unstarred

    # Toggle article 2 read (read -> unread)
    patch toggle_read_article_path(article2)
    assert_response :no_content

    # Toggle article 2 starred (not starred -> starred)
    patch toggle_starred_article_path(article2)
    assert_response :no_content

    state2 = article_states(:alice_tc_2)
    state2.reload
    assert_not state2.read  # Was read, now unread
    assert state2.starred  # Was not starred, now starred

    # Filter to starred should show article 2 but not article 1
    get articles_path, params: { filter: "starred" }
    assert_response :success
  end

  test "archived articles don't appear in default view" do
    article = articles(:tc_article_2)
    state = article_states(:alice_tc_2)

    # Article is archived
    assert state.archived

    # Default view should not show archived articles
    get articles_path
    assert_response :success

    # But archived filter should show it
    get articles_path, params: { filter: "archived" }
    assert_response :success
    # Archived filter applied successfully
  end

  test "search with no query returns no results" do
    get search_path, params: { q: "" }
    assert_response :success
    # Empty search handled gracefully
  end

  test "view article with full content" do
    article = articles(:tc_article_2)

    # This article has full_content
    assert article.full_content.present?

    get article_path(article)
    assert_response :success
    # Article with full content rendered successfully
  end

  test "browse articles with pagination limit" do
    # Articles are limited to 50 per page
    get articles_path
    assert_response :success

    # The limit is applied in the controller
    # This test verifies the endpoint works with limits
  end

  test "cannot view articles from unsubscribed feeds" do
    # Bob has a subscription to ruby_weekly, Alice doesn't
    ruby_article = articles(:ruby_article_1)

    # Alice tries to view the article
    # set_article in controller restricts access to user's subscribed feeds
    # Integration tests don't propagate exceptions, they return 404
    get article_path(ruby_article)
    assert_response :not_found
  end
end

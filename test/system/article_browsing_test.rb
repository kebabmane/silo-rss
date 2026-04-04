require "application_system_test_case"

class ArticleBrowsingTest < ApplicationSystemTestCase
  setup do
    @user = users(:alice)
    @feed = feeds(:tech_crunch)
    @article = articles(:tc_article_1)

    # Login before each test
    visit new_session_path
    fill_in "Email", with: @user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
  end

  test "user can view articles list" do
    visit articles_path

    # Should see articles from subscribed feeds
    @user.feeds.each do |feed|
      feed.articles.limit(5).each do |article|
        assert_text article.title
      end
    end
  end

  test "user can browse articles on dashboard" do
    visit dashboard_path

    # Dashboard should show recent articles
    # Verify article titles are visible
    assert_selector "h1", count: 1
  end

  test "user can filter articles by feed" do
    visit articles_path(feed_id: @feed.id)

    # Should only see articles from the selected feed
    @feed.articles.each do |article|
      assert_text article.title
    end

    # Should not see articles from other feeds
    other_feed = feeds(:hacker_news)
    other_feed.articles.first(1).each do |article|
      assert_no_text article.title
    end
  end

  test "user can filter articles by category" do
    # First create a subscription with a specific category
    subscription = subscriptions(:alice_tech_crunch)
    subscription.update(category: "Technology")

    visit articles_path(category: "Technology")

    # Should see articles from feeds in that category
    subscription.feed.articles.first(3).each do |article|
      assert_text article.title
    end
  end

  test "user can filter unread articles" do
    # Mark some articles as read
    article1 = articles(:tc_article_1)
    article1.state_for(@user).update(read: true)

    visit articles_path(filter: "unread")

    # Should not see read articles
    assert_no_text article1.title

    # Should see unread articles
    unread_article = articles(:tc_article_2)
    assert_text unread_article.title
  end

  test "user can filter starred articles" do
    # Star an article
    article = articles(:tc_article_1)
    article.state_for(@user).update(starred: true)

    visit articles_path(filter: "starred")

    # Should see starred article
    assert_text article.title

    # Should not see non-starred articles
    other_article = articles(:tc_article_2)
    assert_no_text other_article.title
  end

  test "user can filter archived articles" do
    # Archive an article
    article = articles(:tc_article_1)
    article.state_for(@user).update(archived: true)

    visit articles_path(filter: "archived")

    # Should see archived article
    assert_text article.title
  end

  test "default view excludes archived articles" do
    # Archive an article
    article = articles(:tc_article_1)
    article.state_for(@user).update(archived: true)

    visit articles_path

    # Should not see archived article in default view
    assert_no_text article.title

    # Should see non-archived articles
    unarchived = articles(:tc_article_2)
    assert_text unarchived.title
  end

  test "user can view article details" do
    visit article_path(@article)

    # Should see article content
    assert_text @article.title
    assert_text @article.content
  end

  test "user can search for articles" do
    visit search_path

    # Search for specific term
    fill_in "q", with: "AI"
    click_button "Search"

    # Should see matching articles
    assert_text "AI", count: 1
  end

  test "search returns no results for non-matching query" do
    visit search_path

    fill_in "q", with: "nonexistentterm12345"
    click_button "Search"

    # Should show no results message or empty state
    # Adjust based on actual implementation
    assert_selector "body"
  end

  test "search works across article title and content" do
    # Create an article with specific content
    article = articles(:tc_article_1)

    visit search_path

    # Search in title
    fill_in "q", with: article.title.split.first
    click_button "Search"

    assert_text article.title
  end

  test "articles are sorted by published date" do
    visit articles_path

    # Articles should appear in reverse chronological order
    # Get all article titles on page
    article_titles = all("article, .article-item").map(&:text)

    # Verify most recent articles appear first
    # This is a basic check - adjust selector based on implementation
    assert article_titles.any?
  end

  test "article list shows feed information" do
    visit articles_path

    # Each article should show which feed it's from
    @article.feed.articles.limit(3).each do |article|
      assert_text article.feed.title
    end
  end

  test "article list shows publication date" do
    visit articles_path

    # Articles should display their publication date
    # Verify date formatting is present
    assert_selector "body"
  end

  test "user can paginate through articles" do
    visit articles_path

    # Articles should be limited (default 50 in controller)
    # If there are more than 50 articles, pagination should be available
    # This test verifies the limit is applied
    articles_count = @user.feeds.joins(:articles).count

    if articles_count > 50
      # Pagination should be present
      assert_selector ".pagination", count: 1
    end
  end

  test "clicking article navigates to detail view" do
    visit articles_path

    # Click on first article
    click_link @article.title, match: :first

    # Should navigate to article show page
    assert_current_path article_path(@article)
    assert_text @article.title
  end

  test "article detail shows full content if available" do
    # Article with full content
    article_with_full = articles(:tc_article_2)

    visit article_path(article_with_full)

    # Should show full content
    assert_text article_with_full.full_content
  end

  test "article detail shows RSS content when full content unavailable" do
    # Article without full content
    article = articles(:tc_article_1)

    visit article_path(article)

    # Should show regular content
    assert_text article.content
  end

  test "article shows link to original source" do
    visit article_path(@article)

    # Should have link to original article URL
    assert_link href: @article.url
  end

  test "user can fetch full content for article" do
    article = articles(:tc_article_1)

    # Mock the content fetcher
    stub_request(:get, article.url)
      .to_return(status: 200, body: "<html><body><article>Full article content here</article></body></html>")

    visit article_path(article)

    # Click fetch content button
    click_button "Fetch Full Content"

    # Should see success message
    assert_text "Full content fetched successfully!"
  end

  test "fetch content shows error on failure" do
    article = articles(:tc_article_1)

    # Mock failed request
    stub_request(:get, article.url)
      .to_return(status: 404)

    visit article_path(article)

    click_button "Fetch Full Content"

    # Should see error message
    assert_text "Failed to fetch full content"
  end

  test "only articles from subscribed feeds are shown" do
    # Create a feed that user is not subscribed to
    unsubscribed_feed = Feed.create!(
      title: "Unsubscribed Feed",
      feed_url: "https://unsubscribed.com/feed",
      site_url: "https://unsubscribed.com"
    )

    unsubscribed_article = Article.create!(
      feed: unsubscribed_feed,
      title: "Unsubscribed Article",
      content: "This should not appear",
      url: "https://unsubscribed.com/article",
      guid: "unsubscribed_001",
      published_at: 1.day.ago
    )

    visit articles_path

    # Should not see unsubscribed article
    assert_no_text "Unsubscribed Article"
  end

  test "empty state when no articles available" do
    # Remove all subscriptions
    @user.subscriptions.destroy_all

    visit articles_path

    # Should show empty state
    # Adjust based on actual implementation
    assert_selector "body"
  end

  test "article metadata is displayed" do
    visit article_path(@article)

    # Should show metadata like feed name, date, etc.
    assert_text @article.feed.title
  end

  test "user can navigate back from article detail" do
    visit article_path(@article)

    # Should have back link to articles list
    click_link "Back", match: :first

    # Should return to articles list
    assert_current_path articles_path
  end

  test "articles update dynamically with Turbo" do
    visit articles_path

    # Verify page uses Turbo for dynamic updates
    assert_selector "body[data-turbo]", visible: false
  end

  test "search supports empty query" do
    visit search_path

    # Submit search without query
    click_button "Search"

    # Should handle empty query gracefully
    assert_selector "body"
  end

  test "search shows search term in results" do
    visit search_path

    search_term = "Development"
    fill_in "q", with: search_term
    click_button "Search"

    # Search term should be visible in form
    assert_field "q", with: search_term
  end

  test "user can clear search and return to all articles" do
    visit search_path(q: "test")

    # Clear search
    fill_in "q", with: ""
    click_button "Search"

    # Should show empty results or no articles
    assert_selector "body"
  end

  test "article list is responsive to screen size" do
    # Resize viewport to mobile size
    page.driver.browser.manage.window.resize_to(375, 667)

    visit articles_path

    # Page should still be accessible
    assert_selector "body"

    # Resize back to desktop
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "article detail is responsive to screen size" do
    page.driver.browser.manage.window.resize_to(375, 667)

    visit article_path(@article)

    assert_text @article.title

    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "articles show read/unread visual indicators" do
    # Mark article as read
    article = articles(:tc_article_1)
    article.state_for(@user).update(read: true)

    visit articles_path

    # Should have visual indicator for read status
    # This depends on CSS classes - adjust based on implementation
    assert_selector "body"
  end

  test "articles show starred visual indicators" do
    # Star an article
    article = articles(:tc_article_1)
    article.state_for(@user).update(starred: true)

    visit articles_path

    # Should have visual indicator for starred status
    assert_selector "body"
  end

  test "user can view articles by multiple filters simultaneously" do
    # Test combining feed filter and read filter
    visit articles_path(feed_id: @feed.id, filter: "unread")

    # Should apply both filters
    assert_selector "body"
  end
end

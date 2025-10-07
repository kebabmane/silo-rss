require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  test "valid article" do
    article = Article.new(
      feed: feeds(:tech_crunch),
      title: "Test Article",
      content: "Article content",
      url: "https://example.com/article",
      guid: "unique-guid-123",
      published_at: Time.current
    )
    assert article.valid?
  end

  test "requires guid" do
    article = Article.new(
      feed: feeds(:tech_crunch),
      title: "Test Article",
      url: "https://example.com/article"
    )
    assert_not article.valid?
    assert_includes article.errors[:guid], "can't be blank"
  end

  test "requires unique guid scoped to feed" do
    feed = feeds(:tech_crunch)
    Article.create!(feed: feed, guid: "same-guid", title: "First", url: "http://example.com/1")
    duplicate = Article.new(feed: feed, guid: "same-guid", title: "Second", url: "http://example.com/2")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:guid], "has already been taken"
  end

  test "allows same guid for different feeds" do
    feed1 = feeds(:tech_crunch)
    feed2 = feeds(:hacker_news)
    Article.create!(feed: feed1, guid: "same-guid", title: "First", url: "http://example.com/1")
    article2 = Article.new(feed: feed2, guid: "same-guid", title: "Second", url: "http://example.com/2")
    assert article2.valid?
  end

  # Scope tests
  test "recent scope orders by published_at desc" do
    articles = Article.recent
    assert articles.first.published_at >= articles.last.published_at
  end

  test "needs_content_fetch scope finds articles without full_content" do
    article_without_full_content = articles(:tc_article_1)
    article_without_full_content.update!(full_content: nil, content: "short")

    articles_needing_fetch = Article.needs_content_fetch
    assert_includes articles_needing_fetch, article_without_full_content
  end

  test "needs_content_fetch scope excludes articles with full_content" do
    article_with_full_content = articles(:tc_article_2)
    assert article_with_full_content.full_content.present?

    articles_needing_fetch = Article.needs_content_fetch
    assert_not_includes articles_needing_fetch, article_with_full_content
  end

  # Instance method tests
  test "state_for finds existing article state" do
    article = articles(:tc_article_1)
    user = users(:alice)
    existing_state = article_states(:alice_tc_1)

    assert_equal existing_state, article.state_for(user)
  end

  test "state_for creates new article state if none exists" do
    article = articles(:tc_article_1)
    user = users(:charlie)

    assert_difference "ArticleState.count", 1 do
      state = article.state_for(user)
      assert_equal article, state.article
      assert_equal user, state.user
    end
  end

  test "display_content returns full_content when available" do
    article = articles(:tc_article_2)
    assert article.full_content.present?
    assert_equal article.full_content, article.display_content
  end

  test "display_content falls back to content when full_content is nil" do
    article = articles(:tc_article_1)
    assert_nil article.full_content
    assert_equal article.content, article.display_content
  end

  test "full_content_fetched? returns true when full_content exists" do
    article = articles(:tc_article_2)
    assert article.full_content_fetched?
  end

  test "full_content_fetched? returns false when full_content is nil" do
    article = articles(:tc_article_1)
    assert_not article.full_content_fetched?
  end

  test "needs_content_fetch? delegates to ArticleContentFetcherService" do
    article = articles(:tc_article_1)
    ArticleContentFetcherService.expects(:needs_fetch?).with(article).returns(true)
    assert article.needs_content_fetch?
  end

  # Association tests
  test "belongs to feed" do
    article = articles(:tc_article_1)
    assert_respond_to article, :feed
    assert_kind_of Feed, article.feed
  end

  test "has many article_states" do
    article = articles(:tc_article_1)
    assert_respond_to article, :article_states
    assert article.article_states.count > 0
  end

  test "destroys article_states when article is destroyed" do
    article = articles(:tc_article_1)
    article_state_count = article.article_states.count
    assert article_state_count > 0
    assert_difference "ArticleState.count", -article_state_count do
      article.destroy
    end
  end
end

require "test_helper"

class DailyBriefGeneratorServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:alice)
    @feed = feeds(:tech_crunch)
    @subscription = subscriptions(:alice_tech_crunch) || @user.subscriptions.create!(feed: @feed)

    @schedule = daily_brief_schedules(:one)
    @schedule.update!(include_all_feeds: true, summary_length: "medium")

    # Setup LiteLLM
    LitellmSetting.instance.update!(
      enabled: true,
      server_url: "http://localhost:4000",
      default_model: "gpt-3.5-turbo"
    )
  end

  test "generates brief with unread articles" do
    article = @feed.articles.create!(
      title: "Test Article",
      content: "Test content",
      url: "http://example.com/test",
      guid: "test-123",
      published_at: 1.hour.ago
    )

    stub_request(:post, "http://localhost:4000/chat/completions")
      .to_return(
        status: 200,
        body: { choices: [{ message: { content: "AI Summary" } }] }.to_json
      )

    generator = DailyBriefGeneratorService.new(@schedule)
    brief = generator.generate

    assert_not_nil brief
    assert_equal "AI Summary", brief.content
    assert_equal 1, brief.article_count
  end

  test "creates empty brief when no articles" do
    generator = DailyBriefGeneratorService.new(@schedule)
    brief = generator.generate

    assert_not_nil brief
    assert_includes brief.content, "No new articles"
    assert_equal 0, brief.article_count
  end

  test "only includes unread articles from past 24 hours" do
    # Old article
    old_article = @feed.articles.create!(
      title: "Old Article",
      content: "Old content",
      url: "http://example.com/old",
      guid: "old-123",
      published_at: 2.days.ago
    )

    # Recent article
    recent_article = @feed.articles.create!(
      title: "Recent Article",
      content: "Recent content",
      url: "http://example.com/recent",
      guid: "recent-123",
      published_at: 1.hour.ago
    )

    # Read article
    read_article = @feed.articles.create!(
      title: "Read Article",
      content: "Read content",
      url: "http://example.com/read",
      guid: "read-123",
      published_at: 1.hour.ago
    )
    read_article.state_for(@user).update!(read: true)

    stub_request(:post, "http://localhost:4000/chat/completions")
      .to_return(
        status: 200,
        body: { choices: [{ message: { content: "Summary" } }] }.to_json
      )

    generator = DailyBriefGeneratorService.new(@schedule)
    brief = generator.generate

    # Should only include the recent unread article
    assert_equal 1, brief.article_count
  end

  test "provides prompt preview with articles" do
    recent_article = @feed.articles.create!(
      title: "Preview Article",
      content: "Preview content",
      url: "http://example.com/preview",
      guid: "preview-123",
      published_at: 1.hour.ago
    )

    preview = DailyBriefGeneratorService.new(@schedule).prompt_preview

    assert_kind_of Hash, preview
    assert_includes preview, :prompt
    assert_includes preview, :articles
    assert_match /Preview Article/, preview[:prompt]
    assert_equal ["Preview Article"], preview[:articles].map(&:title)
  end
end

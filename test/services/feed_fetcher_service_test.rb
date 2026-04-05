require "test_helper"

class FeedFetcherServiceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @feed = feeds(:tech_crunch)
    @service = FeedFetcherService.new(@feed)
    @sample_feed_xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>TechCrunch</title>
          <link>https://techcrunch.com</link>
          <description>The latest technology news and information on startups</description>
          <item>
            <title>New AI Breakthrough</title>
            <link>https://techcrunch.com/2025/10/04/ai-breakthrough</link>
            <description>Scientists have made a breakthrough in AI research</description>
            <guid>tc_ai_breakthrough_001</guid>
            <pubDate>Thu, 04 Oct 2025 10:00:00 GMT</pubDate>
          </item>
          <item>
            <title>Startup Raises $100M</title>
            <link>https://techcrunch.com/2025/10/04/startup-funding</link>
            <description>A new startup has raised a massive funding round</description>
            <guid>tc_startup_100m_002</guid>
            <pubDate>Thu, 04 Oct 2025 09:00:00 GMT</pubDate>
          </item>
        </channel>
      </rss>
    XML
  end

  # Success scenarios
  test "fetch successfully retrieves and parses feed" do
    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: @sample_feed_xml, headers: { "Content-Type" => "application/rss+xml" })

    articles = @service.fetch

    assert_equal 2, articles.length
    assert_equal "New AI Breakthrough", articles.first.title
    assert_equal "Startup Raises $100M", articles.second.title
  end

  test "fetch creates new articles" do
    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: @sample_feed_xml)

    assert_difference "Article.count", 2 do
      @service.fetch
    end
  end

  test "fetch updates feed last_fetched_at timestamp" do
    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: @sample_feed_xml)

    freeze_time do
      @service.fetch
      @feed.reload
      assert_equal Time.current, @feed.last_fetched_at
    end
  end

  test "fetch does not overwrite existing feed metadata" do
    original_title = @feed.title
    original_site_url = @feed.site_url

    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: @sample_feed_xml)

    @service.fetch
    @feed.reload

    assert_equal original_title, @feed.title
    assert_equal original_site_url, @feed.site_url
  end

  test "fetch does not create duplicate articles" do
    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: @sample_feed_xml)

    # First fetch
    @service.fetch

    # Second fetch with same content
    assert_no_difference "Article.count" do
      @service.fetch
    end
  end

  test "fetch updates existing article when content changes" do
    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: @sample_feed_xml)

    articles = @service.fetch
    original_article = articles.first

    # Update the feed XML with changed content
    updated_xml = @sample_feed_xml.gsub(
      "Scientists have made a breakthrough in AI research",
      "This is updated content about the AI breakthrough"
    )

    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: updated_xml)

    @service.fetch
    original_article.reload

    assert_includes original_article.content, "This is updated content"
  end

  test "fetch does not update article when content is unchanged" do
    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: @sample_feed_xml)

    articles = @service.fetch
    original_updated_at = articles.first.updated_at

    travel 1.hour do
      stub_request(:get, @feed.feed_url)
        .to_return(status: 200, body: @sample_feed_xml)

      @service.fetch
      articles.first.reload

      assert_equal original_updated_at, articles.first.updated_at
    end
  end

  test "fetch generates GUID from entry_id when available" do
    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: @sample_feed_xml)

    articles = @service.fetch

    assert_equal "tc_ai_breakthrough_001", articles.first.guid
  end

  test "fetch generates GUID from URL when entry_id is missing" do
    xml_without_guid = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Test Feed</title>
          <item>
            <title>Article Without GUID</title>
            <link>https://example.com/article</link>
            <description>Content</description>
            <pubDate>Thu, 04 Oct 2025 10:00:00 GMT</pubDate>
          </item>
        </channel>
      </rss>
    XML

    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: xml_without_guid)

    articles = @service.fetch

    assert_equal 1, articles.length
    assert_equal "https://example.com/article", articles.first.guid
  end

  test "fetch generates GUID hash when neither entry_id nor url available" do
    xml_minimal = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Test Feed</title>
          <item>
            <title>Minimal Article</title>
            <description>Content</description>
            <pubDate>Thu, 04 Oct 2025 10:00:00 GMT</pubDate>
          </item>
        </channel>
      </rss>
    XML

    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: xml_minimal)

    articles = @service.fetch

    assert_equal 1, articles.length
    # GUID should be a SHA256 hash
    assert_match(/\A[a-f0-9]{64}\z/, articles.first.guid)
  end

  test "fetch extracts content from various feed fields" do
    xml_with_content_encoded = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0" xmlns:content="http://purl.org/rss/1.0/modules/content/">
        <channel>
          <title>Test Feed</title>
          <item>
            <title>Article with Content Encoded</title>
            <link>https://example.com/article</link>
            <description>Short description</description>
            <content:encoded><![CDATA[This is the full content from content:encoded field with lots of detail and information that makes it much longer than the description field.]]></content:encoded>
            <guid>test_article_001</guid>
            <pubDate>Thu, 04 Oct 2025 10:00:00 GMT</pubDate>
          </item>
        </channel>
      </rss>
    XML

    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: xml_with_content_encoded)

    articles = @service.fetch

    assert_includes articles.first.content, "full content from content:encoded"
  end

  test "fetch removes script tags from content" do
    xml_with_scripts = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Test Feed</title>
          <item>
            <title>Article with Scripts</title>
            <link>https://example.com/article</link>
            <description><![CDATA[
              This is safe content.
              <script>alert('malicious');</script>
              More safe content.
            ]]></description>
            <guid>test_article_002</guid>
            <pubDate>Thu, 04 Oct 2025 10:00:00 GMT</pubDate>
          </item>
        </channel>
      </rss>
    XML

    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: xml_with_scripts)

    articles = @service.fetch

    assert_includes articles.first.content, "This is safe content"
    assert_not_includes articles.first.content, "<script>"
    assert_not_includes articles.first.content, "alert"
  end

  test "fetch queues ArticleContentFetchJob for articles needing full content" do
    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: @sample_feed_xml)

    ArticleContentFetcherService.stubs(:needs_fetch?).returns(true)

    assert_enqueued_with(job: ArticleContentFetchJob) do
      @service.fetch
    end
  end

  test "fetch always queues ArticleContentFetchJob for all articles to ensure full content" do
    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: @sample_feed_xml)

    # Even with sufficient content, jobs are queued to ensure complete content
    assert_enqueued_jobs 2, only: ArticleContentFetchJob do
      @service.fetch
    end
  end

  test "fetch sets published_at to current time when not provided" do
    xml_without_date = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Test Feed</title>
          <item>
            <title>Article Without Date</title>
            <link>https://example.com/article</link>
            <description>Content</description>
            <guid>test_article_003</guid>
          </item>
        </channel>
      </rss>
    XML

    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: xml_without_date)

    freeze_time do
      articles = @service.fetch
      assert_equal Time.current, articles.first.published_at
    end
  end

  # Error scenarios
  test "fetch handles network timeout gracefully" do
    stub_request(:get, @feed.feed_url).to_timeout

    articles = @service.fetch

    assert_equal [], articles
    # Feed should still be updated even on error
    # Actually no, last_fetched_at should not be updated on error
  end

  test "fetch handles HTTP 404 error" do
    stub_request(:get, @feed.feed_url)
      .to_return(status: 404, body: "Not Found")

    articles = @service.fetch

    assert_equal [], articles
  end

  test "fetch handles HTTP 500 error" do
    stub_request(:get, @feed.feed_url)
      .to_return(status: 500, body: "Internal Server Error")

    articles = @service.fetch

    assert_equal [], articles
  end

  test "fetch handles invalid XML" do
    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: "This is not valid XML at all")

    articles = @service.fetch

    assert_equal [], articles
  end

  test "fetch handles malformed feed XML" do
    malformed_xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Test Feed</title>
          <!-- Missing closing tags -->
    XML

    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: malformed_xml)

    articles = @service.fetch

    assert_equal [], articles
  end

  test "fetch handles empty feed" do
    empty_feed_xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Empty Feed</title>
          <link>https://example.com</link>
        </channel>
      </rss>
    XML

    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: empty_feed_xml)

    articles = @service.fetch

    assert_equal [], articles
  end

  test "fetch handles Feedjira parse returning nil" do
    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: "Not a feed")

    Feedjira.stubs(:parse).returns(nil)

    articles = @service.fetch

    assert_equal [], articles
  end

  test "fetch logs error on exception" do
    stub_request(:get, @feed.feed_url).to_raise(StandardError.new("Test error"))

    Rails.logger.expects(:error).with(includes("Feed fetch error"))

    @service.fetch
  end

  test "fetch handles SocketError" do
    stub_request(:get, @feed.feed_url).to_raise(SocketError.new("Connection refused"))

    articles = @service.fetch

    assert_equal [], articles
  end

  test "fetch handles article save failure gracefully" do
    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: @sample_feed_xml)

    # Mock article to fail validation
    Article.any_instance.stubs(:save).returns(false)

    # Should not raise error
    articles = @service.fetch

    # Articles that failed to save won't be in the returned array (compacted)
    assert_equal [], articles
  end

  # Edge cases
  test "fetch strips whitespace from article title" do
    xml_with_whitespace = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Test Feed</title>
          <item>
            <title>
              Article Title With Whitespace
            </title>
            <link>https://example.com/article</link>
            <description>Content</description>
            <guid>test_article_004</guid>
            <pubDate>Thu, 04 Oct 2025 10:00:00 GMT</pubDate>
          </item>
        </channel>
      </rss>
    XML

    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: xml_with_whitespace)

    articles = @service.fetch

    assert_equal "Article Title With Whitespace", articles.first.title
  end

  test "fetch handles Atom feed format" do
    atom_feed_xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <feed xmlns="http://www.w3.org/2005/Atom">
        <title>Atom Feed</title>
        <link href="https://example.com"/>
        <entry>
          <title>Atom Entry</title>
          <link href="https://example.com/entry"/>
          <id>atom_entry_001</id>
          <summary>This is an atom entry</summary>
          <updated>2025-10-04T10:00:00Z</updated>
        </entry>
      </feed>
    XML

    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: atom_feed_xml)

    articles = @service.fetch

    assert_equal 1, articles.length
    assert_equal "Atom Entry", articles.first.title
  end

  test "fetch handles very long content" do
    long_content = "A" * 100000
    xml_with_long_content = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Test Feed</title>
          <item>
            <title>Long Article</title>
            <link>https://example.com/article</link>
            <description>#{long_content}</description>
            <guid>test_article_005</guid>
            <pubDate>Thu, 04 Oct 2025 10:00:00 GMT</pubDate>
          </item>
        </channel>
      </rss>
    XML

    stub_request(:get, @feed.feed_url)
      .to_return(status: 200, body: xml_with_long_content)

    articles = @service.fetch

    assert_equal 1, articles.length
    assert_equal 100000, articles.first.content.length
  end

  test "fetch respects timeout setting" do
    stub_request(:get, @feed.feed_url).to_timeout

    # HTTParty now receives headers for conditional requests along with timeout
    HTTParty.expects(:get).with(
      @feed.feed_url,
      timeout: 15,
      headers: instance_of(Hash)
    ).raises(Net::ReadTimeout)

    @service.fetch
  end
end

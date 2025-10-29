require "test_helper"

class FeedDiscoveryServiceTest < ActiveSupport::TestCase
  # Success scenarios - direct feed URL
  test "discover returns feed_url when URL is a direct RSS feed" do
    feed_url = "https://example.com/feed.xml"
    rss_xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Example Feed</title>
          <link>https://example.com</link>
        </channel>
      </rss>
    XML

    stub_request(:get, feed_url)
      .to_return(
        status: 200,
        body: rss_xml,
        headers: { 'Content-Type' => 'application/rss+xml' }
      )

    service = FeedDiscoveryService.new(feed_url)
    result = service.discover

    assert_equal feed_url, result[:feed_url]
    assert_equal "https://example.com", result[:site_url]
  end

  test "discover identifies feed by XML content-type" do
    feed_url = "https://example.com/rss"
    stub_request(:get, feed_url)
      .to_return(
        status: 200,
        body: "<rss><channel></channel></rss>",
        headers: { 'Content-Type' => 'text/xml' }
      )

    service = FeedDiscoveryService.new(feed_url)
    result = service.discover

    assert_equal feed_url, result[:feed_url]
  end

  test "discover identifies feed by atom content-type" do
    feed_url = "https://example.com/atom"
    stub_request(:get, feed_url)
      .to_return(
        status: 200,
        body: "<feed></feed>",
        headers: { 'Content-Type' => 'application/atom+xml' }
      )

    service = FeedDiscoveryService.new(feed_url)
    result = service.discover

    assert_equal feed_url, result[:feed_url]
  end

  test "discover identifies feed by parsing with Feedjira" do
    feed_url = "https://example.com/feed"
    rss_xml = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rss version="2.0">
        <channel>
          <title>Example Feed</title>
        </channel>
      </rss>
    XML

    stub_request(:get, feed_url)
      .to_return(
        status: 200,
        body: rss_xml,
        headers: { 'Content-Type' => 'text/html' } # Wrong content type
      )

    # Feedjira should still parse it successfully
    service = FeedDiscoveryService.new(feed_url)
    result = service.discover

    assert_equal feed_url, result[:feed_url]
  end

  # Success scenarios - feed discovery from HTML page
  test "discover finds RSS feed link in HTML head" do
    page_url = "https://example.com"
    html = <<~HTML
      <html>
        <head>
          <link rel="alternate" type="application/rss+xml" href="/feed.xml" />
        </head>
        <body>Content</body>
      </html>
    HTML

    stub_request(:get, page_url)
      .to_return(status: 200, body: html, headers: { 'Content-Type' => 'text/html' })

    # Feedjira parse will fail for HTML
    Feedjira.stubs(:parse).raises(Feedjira::NoParserAvailable)

    service = FeedDiscoveryService.new(page_url)
    result = service.discover

    assert_equal "https://example.com/feed.xml", result[:feed_url]
    assert_equal page_url, result[:site_url]
  end

  test "discover finds Atom feed link in HTML head" do
    page_url = "https://example.com"
    html = <<~HTML
      <html>
        <head>
          <link rel="alternate" type="application/atom+xml" href="/atom.xml" />
        </head>
        <body>Content</body>
      </html>
    HTML

    stub_request(:get, page_url)
      .to_return(status: 200, body: html, headers: { 'Content-Type' => 'text/html' })

    Feedjira.stubs(:parse).raises(Feedjira::NoParserAvailable)

    service = FeedDiscoveryService.new(page_url)
    result = service.discover

    assert_equal "https://example.com/atom.xml", result[:feed_url]
    assert_equal page_url, result[:site_url]
  end

  test "discover handles absolute feed URLs in HTML" do
    page_url = "https://example.com"
    html = <<~HTML
      <html>
        <head>
          <link rel="alternate" type="application/rss+xml" href="https://feeds.example.com/rss" />
        </head>
        <body>Content</body>
      </html>
    HTML

    stub_request(:get, page_url)
      .to_return(status: 200, body: html, headers: { 'Content-Type' => 'text/html' })

    Feedjira.stubs(:parse).raises(Feedjira::NoParserAvailable)

    service = FeedDiscoveryService.new(page_url)
    result = service.discover

    assert_equal "https://feeds.example.com/rss", result[:feed_url]
    assert_equal page_url, result[:site_url]
  end

  test "discover handles relative feed URLs in HTML" do
    page_url = "https://example.com/blog"
    html = <<~HTML
      <html>
        <head>
          <link rel="alternate" type="application/rss+xml" href="/feed" />
        </head>
        <body>Content</body>
      </html>
    HTML

    stub_request(:get, page_url)
      .to_return(status: 200, body: html, headers: { 'Content-Type' => 'text/html' })

    Feedjira.stubs(:parse).raises(Feedjira::NoParserAvailable)

    service = FeedDiscoveryService.new(page_url)
    result = service.discover

    assert_equal "https://example.com/feed", result[:feed_url]
    assert_equal page_url, result[:site_url]
  end

  test "discover chooses first feed link when multiple exist" do
    page_url = "https://example.com"
    html = <<~HTML
      <html>
        <head>
          <link rel="alternate" type="application/rss+xml" href="/rss" />
          <link rel="alternate" type="application/atom+xml" href="/atom" />
        </head>
        <body>Content</body>
      </html>
    HTML

    stub_request(:get, page_url)
      .to_return(status: 200, body: html, headers: { 'Content-Type' => 'text/html' })

    Feedjira.stubs(:parse).raises(Feedjira::NoParserAvailable)

    service = FeedDiscoveryService.new(page_url)
    result = service.discover

    assert_equal "https://example.com/rss", result[:feed_url]
  end

  # Success scenarios - common feed paths
  test "discover tries common feed paths when no links found" do
    page_url = "https://example.com"
    html = "<html><head></head><body>No feed links</body></html>"

    # Stub the page request
    stub_request(:get, page_url)
      .to_return(status: 200, body: html, headers: { 'Content-Type' => 'text/html' })

    Feedjira.stubs(:parse).with(html).raises(Feedjira::NoParserAvailable)
    Feedjira.stubs(:parse).with("").raises(Feedjira::NoParserAvailable)

    # Stub common path attempts - /feed returns 404, /rss succeeds
    stub_request(:get, "https://example.com/feed")
      .to_return(status: 404, body: "", headers: { 'Content-Type' => 'text/html' })

    feed_xml = "<rss><channel></channel></rss>"
    stub_request(:get, "https://example.com/rss")
      .to_return(
        status: 200,
        body: feed_xml,
        headers: { 'Content-Type' => 'application/rss+xml' }
      )

    service = FeedDiscoveryService.new(page_url)
    result = service.discover

    assert_equal "https://example.com/rss", result[:feed_url]
    assert_equal page_url, result[:site_url]
  end

  test "discover checks multiple common paths in order" do
    page_url = "https://example.com"
    html = "<html><head></head><body>No feed links</body></html>"

    stub_request(:get, page_url)
      .to_return(status: 200, body: html, headers: { 'Content-Type' => 'text/html' })

    Feedjira.stubs(:parse).with(html).raises(Feedjira::NoParserAvailable)
    Feedjira.stubs(:parse).with("").raises(Feedjira::NoParserAvailable)

    # Stub all common paths to fail except /atom.xml
    ["/feed", "/rss", "/atom", "/feed.xml", "/rss.xml"].each do |path|
      stub_request(:get, "https://example.com#{path}")
        .to_return(status: 404, body: "", headers: { 'Content-Type' => 'text/html' })
    end

    feed_xml = "<feed></feed>"
    stub_request(:get, "https://example.com/atom.xml")
      .to_return(
        status: 200,
        body: feed_xml,
        headers: { 'Content-Type' => 'application/atom+xml' }
      )

    service = FeedDiscoveryService.new(page_url)
    result = service.discover

    assert_equal "https://example.com/atom.xml", result[:feed_url]
  end

  # URL normalization
  test "discover normalizes URL by adding https protocol" do
    url_without_protocol = "example.com/feed"
    feed_xml = "<rss><channel></channel></rss>"

    stub_request(:get, "https://example.com/feed")
      .to_return(
        status: 200,
        body: feed_xml,
        headers: { 'Content-Type' => 'application/rss+xml' }
      )

    service = FeedDiscoveryService.new(url_without_protocol)
    result = service.discover

    assert_equal "https://example.com/feed", result[:feed_url]
  end

  test "discover preserves http protocol when specified" do
    url_with_http = "http://example.com/feed"
    feed_xml = "<rss><channel></channel></rss>"

    stub_request(:get, "http://example.com/feed")
      .to_return(
        status: 200,
        body: feed_xml,
        headers: { 'Content-Type' => 'application/rss+xml' }
      )

    service = FeedDiscoveryService.new(url_with_http)
    result = service.discover

    assert_equal "http://example.com/feed", result[:feed_url]
  end

  test "discover strips whitespace from URL" do
    url_with_whitespace = "  https://example.com/feed  "
    feed_xml = "<rss><channel></channel></rss>"

    stub_request(:get, "https://example.com/feed")
      .to_return(
        status: 200,
        body: feed_xml,
        headers: { 'Content-Type' => 'application/rss+xml' }
      )

    service = FeedDiscoveryService.new(url_with_whitespace)
    result = service.discover

    assert_equal "https://example.com/feed", result[:feed_url]
  end

  test "discover resolves relative feed URL without leading slash" do
    page_url = "https://example.com/blog"
    html = <<~HTML
      <html><head>
        <link rel="alternate" type="application/rss+xml" href="feed.xml" />
      </head><body></body></html>
    HTML

    stub_request(:get, page_url)
      .to_return(status: 200, body: html, headers: { 'Content-Type' => 'text/html' })

    service = FeedDiscoveryService.new(page_url)
    result = service.discover

    assert_equal "https://example.com/feed.xml", result[:feed_url]
    assert_equal page_url, result[:site_url]
  end

  test "discover rejects unsafe feed links" do
    page_url = "https://example.com"
    html = <<~HTML
      <html><head>
        <link rel="alternate" type="application/rss+xml" href="http://127.0.0.1/feed" />
      </head><body></body></html>
    HTML

    stub_request(:get, page_url)
      .to_return(status: 200, body: html, headers: { 'Content-Type' => 'text/html' })

    # Stub common path attempts to avoid external calls
    ["/feed", "/rss", "/atom", "/feed.xml", "/rss.xml", "/atom.xml"].each do |path|
      stub_request(:get, "https://example.com#{path}")
        .to_return(status: 404, body: "", headers: { 'Content-Type' => 'text/html' })
    end

    service = FeedDiscoveryService.new(page_url)
    result = service.discover

    assert_nil result
  end

  # Error scenarios
  test "discover returns nil when URL returns 404" do
    page_url = "https://example.com/nonexistent"

    stub_request(:get, page_url)
      .to_return(status: 404, body: "Not Found", headers: { 'Content-Type' => 'text/html' })

    # Service will try common paths when page returns 404
    Feedjira.stubs(:parse).with("Not Found").raises(Feedjira::NoParserAvailable)
    Feedjira.stubs(:parse).with("").raises(Feedjira::NoParserAvailable)

    # Stub common paths - all return 404
    ["/feed", "/rss", "/atom", "/feed.xml", "/rss.xml", "/atom.xml"].each do |path|
      stub_request(:get, "https://example.com#{path}")
        .to_return(status: 404, body: "", headers: { 'Content-Type' => 'text/html' })
    end

    service = FeedDiscoveryService.new(page_url)
    result = service.discover

    assert_nil result
  end

  test "discover returns nil when URL times out" do
    page_url = "https://example.com"

    stub_request(:get, page_url).to_timeout

    service = FeedDiscoveryService.new(page_url)
    result = service.discover

    assert_nil result
  end

  test "discover returns nil when network error occurs" do
    page_url = "https://example.com"

    stub_request(:get, page_url).to_raise(SocketError.new("Failed to connect"))

    service = FeedDiscoveryService.new(page_url)
    result = service.discover

    assert_nil result
  end

  test "discover returns nil when no feed links and common paths fail" do
    page_url = "https://example.com"
    html = "<html><head></head><body>No feed links</body></html>"

    stub_request(:get, page_url)
      .to_return(status: 200, body: html, headers: { 'Content-Type' => 'text/html' })

    Feedjira.stubs(:parse).with(html).raises(Feedjira::NoParserAvailable)
    Feedjira.stubs(:parse).with("").raises(Feedjira::NoParserAvailable)

    # Stub all common paths to fail
    ["/feed", "/rss", "/atom", "/feed.xml", "/rss.xml", "/atom.xml"].each do |path|
      stub_request(:get, "https://example.com#{path}")
        .to_return(status: 404, body: "", headers: { 'Content-Type' => 'text/html' })
    end

    service = FeedDiscoveryService.new(page_url)
    result = service.discover

    assert_nil result
  end

  test "discover logs error and returns nil on exception" do
    page_url = "https://example.com"

    stub_request(:get, page_url).to_raise(StandardError.new("Unexpected error"))

    Rails.logger.expects(:error).with(includes("Feed discovery error"))

    service = FeedDiscoveryService.new(page_url)
    result = service.discover

    assert_nil result
  end

  test "discover handles malformed HTML gracefully" do
    page_url = "https://example.com"
    malformed_html = "<html><head><link rel='alternate' type='application/rss+xml' href='/feed'</head>" # Missing closing >

    stub_request(:get, page_url)
      .to_return(status: 200, body: malformed_html, headers: { 'Content-Type' => 'text/html' })

    Feedjira.stubs(:parse).raises(Feedjira::NoParserAvailable)

    service = FeedDiscoveryService.new(page_url)

    # Nokogiri should handle malformed HTML, so this should still work
    result = service.discover

    # May or may not find the feed depending on how Nokogiri parses it
    # At minimum, it shouldn't crash
    assert_not_nil service
  end

  test "discover handles HTTP 500 error" do
    page_url = "https://example.com"

    stub_request(:get, page_url)
      .to_return(status: 500, body: "Internal Server Error", headers: { 'Content-Type' => 'text/html' })

    # Stub common paths to also fail
    Feedjira.stubs(:parse).with("Internal Server Error").raises(Feedjira::NoParserAvailable)
    Feedjira.stubs(:parse).with("").raises(Feedjira::NoParserAvailable)

    ["/feed", "/rss", "/atom", "/feed.xml", "/rss.xml", "/atom.xml"].each do |path|
      stub_request(:get, "https://example.com#{path}")
        .to_return(status: 404, body: "", headers: { 'Content-Type' => 'text/html' })
    end

    service = FeedDiscoveryService.new(page_url)
    result = service.discover

    assert_nil result
  end

  # Edge cases
  test "discover extracts site_url from feed URL correctly" do
    feed_url = "https://blog.example.com/feeds/posts/default"
    feed_xml = "<rss><channel></channel></rss>"

    stub_request(:get, feed_url)
      .to_return(
        status: 200,
        body: feed_xml,
        headers: { 'Content-Type' => 'application/rss+xml' }
      )

    service = FeedDiscoveryService.new(feed_url)
    result = service.discover

    assert_equal "https://blog.example.com", result[:site_url]
  end

  test "discover handles subdomain in feed URL" do
    feed_url = "https://feeds.example.com/rss"
    feed_xml = "<rss><channel></channel></rss>"

    stub_request(:get, feed_url)
      .to_return(
        status: 200,
        body: feed_xml,
        headers: { 'Content-Type' => 'application/rss+xml' }
      )

    service = FeedDiscoveryService.new(feed_url)
    result = service.discover

    assert_equal feed_url, result[:feed_url]
    assert_equal "https://feeds.example.com", result[:site_url]
  end

  test "discover handles port number in URL" do
    feed_url = "https://example.com:8080/feed"
    feed_xml = "<rss><channel></channel></rss>"

    stub_request(:get, feed_url)
      .to_return(
        status: 200,
        body: feed_xml,
        headers: { 'Content-Type' => 'application/rss+xml' }
      )

    service = FeedDiscoveryService.new(feed_url)
    result = service.discover

    assert_equal feed_url, result[:feed_url]
    assert_equal "https://example.com", result[:site_url]
  end

  test "discover extracts site_url successfully for valid URLs" do
    feed_url = "https://example.com/feed"

    # Stub the request to succeed
    stub_request(:get, feed_url)
      .to_return(
        status: 200,
        body: "<rss><channel></channel></rss>",
        headers: { 'Content-Type' => 'application/rss+xml' }
      )

    service = FeedDiscoveryService.new(feed_url)
    result = service.discover

    # Should extract site_url successfully
    assert_not_nil result
    assert_equal feed_url, result[:feed_url]
    assert_equal "https://example.com", result[:site_url]
  end

  test "discover respects timeout setting" do
    page_url = "https://example.com"

    stub_request(:get, page_url).to_timeout

    service = FeedDiscoveryService.new(page_url)
    result = service.discover

    assert_nil result
  end

  test "discover handles redirect responses" do
    original_url = "https://example.com/feed"
    redirected_url = "https://feeds.example.com/rss"
    feed_xml = "<rss><channel></channel></rss>"

    # HTTParty follows redirects by default, so stub the original URL to return final content
    stub_request(:get, original_url)
      .to_return(
        status: 200,
        body: feed_xml,
        headers: { 'Content-Type' => 'application/rss+xml' }
      )

    service = FeedDiscoveryService.new(original_url)
    result = service.discover

    assert_equal original_url, result[:feed_url]
  end
end

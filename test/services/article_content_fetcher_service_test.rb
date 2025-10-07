require "test_helper"

class ArticleContentFetcherServiceTest < ActiveSupport::TestCase
  setup do
    @article = articles(:tc_article_1)
    @article.update!(full_content: nil, content: "Short summary")
    @service = ArticleContentFetcherService.new(@article)
  end

  # Success scenarios
  test "fetch successfully extracts content from article URL" do
    html = <<~HTML
      <html>
        <head><title>Article Title</title></head>
        <body>
          <article>
            <h1>Main Article Heading</h1>
            <p>This is the main content of the article with substantial text that should be extracted.</p>
            <p>More paragraphs with important information that readers need to see.</p>
          </article>
          <div class="sidebar">Advertisement</div>
          <footer>Footer content</footer>
        </body>
      </html>
    HTML

    stub_request(:get, @article.url)
      .to_return(status: 200, body: html, headers: { 'Content-Type' => 'text/html' })

    result = @service.fetch

    assert result
    @article.reload
    assert @article.full_content.present?
    assert @article.full_content.length > 100
  end

  test "fetch saves extracted content to article" do
    html = <<~HTML
      <html>
        <body>
          <article>
            <p>#{"Lorem ipsum dolor sit amet. " * 20}</p>
          </article>
        </body>
      </html>
    HTML

    stub_request(:get, @article.url)
      .to_return(status: 200, body: html)

    @service.fetch
    @article.reload

    assert @article.full_content.present?
    assert_includes @article.full_content, "Lorem ipsum"
  end

  test "fetch logs success message" do
    html = "<html><body><article><p>#{"Content " * 50}</p></article></body></html>"

    stub_request(:get, @article.url)
      .to_return(status: 200, body: html)

    Rails.logger.expects(:info).with(includes("Fetched full content for article"))

    @service.fetch
  end

  test "fetch returns true on successful extraction" do
    html = "<html><body><article><p>#{"Content " * 50}</p></article></body></html>"

    stub_request(:get, @article.url)
      .to_return(status: 200, body: html)

    result = @service.fetch

    assert_equal true, result
  end

  test "fetch extracts content with allowed tags" do
    html = <<~HTML
      <html>
        <body>
          <article>
            <h1>Heading 1</h1>
            <h2>Heading 2</h2>
            <p>Paragraph with <a href="https://example.com">link</a></p>
            <img src="https://example.com/image.jpg" alt="Test image">
            <blockquote>A quote</blockquote>
            <ul>
              <li>List item 1</li>
              <li>List item 2</li>
            </ul>
            <pre><code>code block</code></pre>
          </article>
        </body>
      </html>
    HTML

    stub_request(:get, @article.url)
      .to_return(status: 200, body: html)

    @service.fetch
    @article.reload

    # Check that content is extracted (Readability may restructure/remove some tags)
    assert_includes @article.full_content, "Heading 1"
    assert_includes @article.full_content, "Paragraph with"
    assert_includes @article.full_content, "link"
  end

  test "fetch removes unwanted content like ads and navigation" do
    html = <<~HTML
      <html>
        <body>
          <nav>Navigation menu</nav>
          <aside class="ads">Advertisement content</aside>
          <article>
            <p>#{"Main article content. " * 30}</p>
          </article>
          <footer>Footer</footer>
        </body>
      </html>
    HTML

    stub_request(:get, @article.url)
      .to_return(status: 200, body: html)

    @service.fetch
    @article.reload

    # Readability should extract only main content
    assert_includes @article.full_content, "Main article content"
    # Navigation and ads should ideally be removed (Readability does this)
  end

  test "fetch handles complex HTML structure" do
    html = <<~HTML
      <html>
        <head>
          <script>alert('test');</script>
          <style>.test { color: red; }</style>
        </head>
        <body>
          <div class="container">
            <div class="content">
              <article>
                <div class="article-body">
                  <p>#{"This is a very long article with lots of content. " * 25}</p>
                </div>
              </article>
            </div>
          </div>
        </body>
      </html>
    HTML

    stub_request(:get, @article.url)
      .to_return(status: 200, body: html)

    result = @service.fetch

    assert result
    @article.reload
    assert @article.full_content.present?
  end

  test "fetch follows redirects" do
    redirect_url = "https://example.com/redirected-article"
    final_html = "<html><body><article><p>#{"Content " * 50}</p></article></body></html>"

    # HTTParty follows redirects by default, so stub the original URL to return final content
    stub_request(:get, @article.url)
      .to_return(status: 200, body: final_html, headers: { 'Content-Type' => 'text/html' })

    result = @service.fetch

    assert result
  end

  # Early return scenarios
  test "fetch returns early when article URL is blank" do
    @article.update!(url: nil)
    service = ArticleContentFetcherService.new(@article)

    result = service.fetch

    assert_nil result
    assert_nil @article.full_content
  end

  test "fetch returns early when article URL is empty string" do
    @article.update!(url: "")
    service = ArticleContentFetcherService.new(@article)

    result = service.fetch

    assert_nil result
  end

  test "fetch returns early when full_content already exists" do
    @article.update!(full_content: "Already fetched content")
    service = ArticleContentFetcherService.new(@article)

    # Should not make any HTTP requests
    stub_request(:get, @article.url).to_return(status: 200, body: "New content")

    result = service.fetch

    assert_nil result
    assert_equal "Already fetched content", @article.reload.full_content
  end

  # Error scenarios
  test "fetch returns false when HTTP request fails with 404" do
    stub_request(:get, @article.url)
      .to_return(status: 404, body: "Not Found")

    result = @service.fetch

    assert_equal false, result
    @article.reload
    assert_nil @article.full_content
  end

  test "fetch returns false when HTTP request fails with 500" do
    stub_request(:get, @article.url)
      .to_return(status: 500, body: "Internal Server Error")

    result = @service.fetch

    assert_equal false, result
    assert_nil @article.reload.full_content
  end

  test "fetch returns false on network timeout" do
    stub_request(:get, @article.url).to_timeout

    result = @service.fetch

    assert_equal false, result
    assert_nil @article.reload.full_content
  end

  test "fetch logs HTTP error" do
    stub_request(:get, @article.url).to_timeout

    Rails.logger.expects(:error).with(includes("HTTP error fetching content"))

    @service.fetch
  end

  test "fetch handles socket error" do
    stub_request(:get, @article.url).to_raise(SocketError.new("Connection failed"))

    Rails.logger.expects(:error).with(includes("HTTP error fetching content"))

    result = @service.fetch

    assert_equal false, result
  end

  test "fetch handles HTTParty error" do
    stub_request(:get, @article.url).to_raise(HTTParty::Error.new("Request failed"))

    Rails.logger.expects(:error).with(includes("HTTP error fetching content"))

    result = @service.fetch

    assert_equal false, result
  end

  test "fetch handles generic errors gracefully" do
    stub_request(:get, @article.url)
      .to_return(status: 200, body: "content")

    Readability::Document.stubs(:new).raises(StandardError.new("Parsing error"))

    Rails.logger.expects(:error).with(includes("Error fetching content"))

    result = @service.fetch

    assert_equal false, result
  end

  test "fetch returns false when extracted content is too short" do
    short_html = <<~HTML
      <html>
        <body>
          <article>
            <p>Short content</p>
          </article>
        </body>
      </html>
    HTML

    stub_request(:get, @article.url)
      .to_return(status: 200, body: short_html)

    Rails.logger.expects(:warn).with(includes("Insufficient content extracted"))

    result = @service.fetch

    assert_equal false, result
    @article.reload
    assert_nil @article.full_content
  end

  test "fetch returns false when extracted content is empty" do
    empty_html = <<~HTML
      <html>
        <body>
          <div>No article content here</div>
        </body>
      </html>
    HTML

    stub_request(:get, @article.url)
      .to_return(status: 200, body: empty_html)

    result = @service.fetch

    assert_equal false, result
  end

  test "fetch returns false when extracted content is nil" do
    html = "<html><body><div>Content</div></body></html>"

    stub_request(:get, @article.url)
      .to_return(status: 200, body: html)

    Readability::Document.any_instance.stubs(:content).returns(nil)

    result = @service.fetch

    assert_equal false, result
  end

  # Edge cases
  test "fetch handles HTML with encoding issues" do
    # HTML with special characters
    html = <<~HTML
      <html>
        <head><meta charset="UTF-8"></head>
        <body>
          <article>
            <p>#{"Content with special chars: é, ñ, ü, 中文. " * 30}</p>
          </article>
        </body>
      </html>
    HTML

    stub_request(:get, @article.url)
      .to_return(status: 200, body: html.force_encoding('UTF-8'))

    result = @service.fetch

    assert result
    @article.reload
    assert @article.full_content.present?
  end

  test "fetch handles content exactly 100 characters" do
    # Content exactly at the threshold
    exact_content = "a" * 100
    html = "<html><body><article><p>#{exact_content}</p></article></body></html>"

    stub_request(:get, @article.url)
      .to_return(status: 200, body: html)

    Readability::Document.any_instance.stubs(:content).returns(exact_content)

    result = @service.fetch

    # Should be false because content needs to be > 100
    assert_equal false, result
  end

  test "fetch handles content of 101 characters" do
    # Content just over the threshold
    valid_content = "a" * 101
    html = "<html><body><article><p>#{valid_content}</p></article></body></html>"

    stub_request(:get, @article.url)
      .to_return(status: 200, body: html)

    Readability::Document.any_instance.stubs(:content).returns(valid_content)

    result = @service.fetch

    assert result
  end

  test "fetch passes correct tags to Readability" do
    html = "<html><body><article><p>Content</p></article></body></html>"

    stub_request(:get, @article.url)
      .to_return(status: 200, body: html)

    expected_tags = %w[div p img a h1 h2 h3 h4 h5 h6 blockquote ul ol li pre code]
    expected_attributes = %w[href src alt]

    mock_doc = mock('readability_doc')
    mock_doc.stubs(:content).returns("a" * 101)

    Readability::Document.expects(:new).with(
      html,
      tags: expected_tags,
      attributes: expected_attributes,
      remove_empty_nodes: true
    ).returns(mock_doc)

    @service.fetch
  end

  test "fetch respects timeout setting" do
    stub_request(:get, @article.url).to_timeout

    HTTParty.expects(:get).with(@article.url, timeout: 15, follow_redirects: true).raises(Timeout::Error)

    @service.fetch
  end

  test "fetch handles very long content" do
    very_long_content = "Word " * 100000
    html = "<html><body><article><p>#{very_long_content}</p></article></body></html>"

    stub_request(:get, @article.url)
      .to_return(status: 200, body: html)

    result = @service.fetch

    assert result
    @article.reload
    assert @article.full_content.length > 100
  end

  test "fetch handles content with only whitespace" do
    whitespace_html = <<~HTML
      <html>
        <body>
          <article>
            <p>

            </p>
          </article>
        </body>
      </html>
    HTML

    stub_request(:get, @article.url)
      .to_return(status: 200, body: whitespace_html)

    result = @service.fetch

    assert_equal false, result
  end

  # Class method: needs_fetch?
  test "needs_fetch? returns false when URL is blank" do
    article = Article.new(url: nil, content: "Short", full_content: nil)

    result = ArticleContentFetcherService.needs_fetch?(article)

    assert_equal false, result
  end

  test "needs_fetch? returns false when full_content is present" do
    article = Article.new(url: "https://example.com", content: "Short", full_content: "Long content")

    result = ArticleContentFetcherService.needs_fetch?(article)

    assert_equal false, result
  end

  test "needs_fetch? returns true when content is short and full_content is nil" do
    article = Article.new(url: "https://example.com", content: "Short summary", full_content: nil)

    result = ArticleContentFetcherService.needs_fetch?(article)

    assert result
  end

  test "needs_fetch? returns false when content is long enough" do
    long_content = "a" * 500
    article = Article.new(url: "https://example.com", content: long_content, full_content: nil)

    result = ArticleContentFetcherService.needs_fetch?(article)

    assert_equal false, result
  end

  test "needs_fetch? threshold is 500 characters" do
    # Content with exactly 499 characters should need fetch
    content_499 = "a" * 499
    article_short = Article.new(url: "https://example.com", content: content_499, full_content: nil)

    assert ArticleContentFetcherService.needs_fetch?(article_short)

    # Content with 500 characters should NOT need fetch
    content_500 = "a" * 500
    article_long = Article.new(url: "https://example.com", content: content_500, full_content: nil)

    assert_equal false, ArticleContentFetcherService.needs_fetch?(article_long)
  end

  test "needs_fetch? handles nil content" do
    article = Article.new(url: "https://example.com", content: nil, full_content: nil)

    result = ArticleContentFetcherService.needs_fetch?(article)

    assert result
  end

  test "needs_fetch? handles empty string content" do
    article = Article.new(url: "https://example.com", content: "", full_content: nil)

    result = ArticleContentFetcherService.needs_fetch?(article)

    assert result
  end

  test "needs_fetch? strips whitespace when checking content length" do
    whitespace_content = "   Short   "
    article = Article.new(url: "https://example.com", content: whitespace_content, full_content: nil)

    result = ArticleContentFetcherService.needs_fetch?(article)

    assert result
  end

  test "needs_fetch? works with fixture articles" do
    article_needing_fetch = articles(:tc_article_1)
    article_needing_fetch.update!(content: "Short", full_content: nil)

    assert ArticleContentFetcherService.needs_fetch?(article_needing_fetch)

    article_with_full_content = articles(:tc_article_2)

    assert_equal false, ArticleContentFetcherService.needs_fetch?(article_with_full_content)
  end
end

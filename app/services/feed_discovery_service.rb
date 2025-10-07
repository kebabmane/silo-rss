class FeedDiscoveryService
  def initialize(url)
    @url = normalize_url(url)
  end

  def discover
    return if @url.blank?

    # First, try the URL as a direct feed
    if feed_url?(@url)
      return { feed_url: @url, site_url: extract_site_url(@url) }
    end

    # Otherwise, try to discover feeds from the webpage
    discover_from_page
  end

  private

  def normalize_url(url)
    raw = url.to_s.strip
    return if raw.blank?

    raw = "https://#{raw}" unless raw.match?(/^https?:\/\//)
    uri = UrlSafety.safe_uri_for(raw)
    unless uri
      Rails.logger.warn("Feed discovery rejected unsafe URL: #{raw}")
      return
    end

    uri.to_s
  end

  def feed_url?(url)
    uri = UrlSafety.safe_uri_for(url)
    return false unless uri

    response = HTTParty.get(uri.to_s, timeout: 10)
    content_type = response.headers["content-type"]

    # Check if it's an RSS/Atom feed by content type or by parsing
    return true if content_type&.include?("xml") || content_type&.include?("rss") || content_type&.include?("atom")

    # Try to parse as feed
    begin
      Feedjira.parse(response.body)
      true
    rescue
      false
    end
  rescue
    false
  end

  def discover_from_page
    uri = UrlSafety.safe_uri_for(@url)
    return unless uri

    response = HTTParty.get(uri.to_s, timeout: 10)
    doc = Nokogiri::HTML(response.body)

    # Look for feed links in the HTML head
    feed_links = doc.css('link[type="application/rss+xml"], link[type="application/atom+xml"]')

    if feed_links.any?
      feed_link = feed_links.first
      feed_url = feed_link["href"]

      # Make feed URL absolute if it's relative
      feed_url = URI.join(@url, feed_url).to_s if feed_url.start_with?("/")

      return { feed_url: feed_url, site_url: @url }
    end

    # If no feed links found, try common feed URLs
    try_common_feed_urls
  rescue => e
    Rails.logger.error("Feed discovery error: #{e.message}")
    nil
  end

  def try_common_feed_urls
    return nil if @url.blank?

    base_uri = URI.parse(@url)
    common_paths = ["/feed", "/rss", "/atom", "/feed.xml", "/rss.xml", "/atom.xml"]

    common_paths.each do |path|
      test_url = "#{base_uri.scheme}://#{base_uri.host}#{path}"
      if feed_url?(test_url)
        return { feed_url: test_url, site_url: @url }
      end
    end

    nil
  end

  def extract_site_url(feed_url)
    uri = URI.parse(feed_url)
    "#{uri.scheme}://#{uri.host}"
  rescue
    feed_url
  end
end

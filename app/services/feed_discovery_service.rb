# frozen_string_literal: true

class FeedDiscoveryService
  CACHE_TTL = 1.day

  def initialize(url)
    @url = normalize_url(url)
    @cache_key = "feed_discovery:#{Digest::SHA256.hexdigest(@url.to_s)}" if @url.present?
  end

  def discover
    return Result.failure(:invalid_input, "URL is blank") if @url.blank?

    # Check cache first
    cached_result = check_cache
    return cached_result if cached_result.present?

    # First, try the URL as a direct feed
    if feed_url?(@url)
      result = Result.success(
        data: { feed_url: @url, site_url: extract_site_url(@url) },
        meta: { source: :direct, cached: false }
      )
      store_cache(result)
      return result
    end

    # Otherwise, try to discover feeds from the webpage
    result = discover_from_page
    store_cache(result) if result.success?
    result
  end

  private

  def check_cache
    return nil unless @cache_key

    cached = Rails.cache.read(@cache_key)
    return nil unless cached

    Result.success(
      data: cached[:data],
      meta: cached[:meta]&.merge(cached: true) || { cached: true }
    )
  rescue => e
    Rails.logger.warn("Feed discovery cache read error: #{e.message}")
    nil
  end

  def store_cache(result)
    return unless @cache_key && result.success?

    Rails.cache.write(
      @cache_key,
      { data: result.data, meta: result.meta },
      expires_in: CACHE_TTL
    )
  rescue => e
    Rails.logger.warn("Feed discovery cache write error: #{e.message}")
  end

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

    response = HTTParty.get(uri.to_s, timeout: 5)
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
    return Result.failure(:invalid_input, "Invalid URL") unless uri

    response = HTTParty.get(uri.to_s, timeout: 10)
    doc = Nokogiri::HTML(response.body)

    # Look for feed links in the HTML head
    feed_links = doc.css('link[type="application/rss+xml"], link[type="application/atom+xml"]')

    if feed_links.any?
      feed_link = feed_links.first
      feed_url = build_safe_feed_url(feed_link["href"])
      if feed_url
        return Result.success(
          data: { feed_url: feed_url, site_url: @url },
          meta: { source: :html_link, cached: false }
        )
      end
    end

    # If no feed links found, try common feed URLs
    try_common_feed_urls
  rescue => e
    Rails.logger.error("Feed discovery error: #{e.message}")
    Result.failure(:network_error, e.message, retryable: true)
  end

  def try_common_feed_urls
    return Result.failure(:not_found, "No feed found for URL") if @url.blank?

    base_uri = URI.parse(@url)
    common_paths = [ "/feed", "/rss", "/atom", "/feed.xml", "/rss.xml", "/atom.xml" ]

    common_paths.each do |path|
      test_url = "#{base_uri.scheme}://#{base_uri.host}#{path}"
      safe_url = build_safe_feed_url(test_url)
      if safe_url && feed_url?(safe_url)
        return Result.success(
          data: { feed_url: safe_url, site_url: @url },
          meta: { source: :common_path, path: path, cached: false }
        )
      end
    end

    Result.failure(:not_found, "No feed found at #{@url} or common paths")
  rescue => e
    Rails.logger.error("Feed discovery common paths error: #{e.message}")
    Result.failure(:network_error, e.message, retryable: true)
  end

  def extract_site_url(feed_url)
    uri = URI.parse(feed_url)
    "#{uri.scheme}://#{uri.host}"
  rescue
    feed_url
  end

  def build_safe_feed_url(candidate)
    return if candidate.blank?

    absolute_url = begin
      uri = URI.parse(candidate.to_s.strip)
      uri = URI.join(@url, candidate) if uri.relative?
      uri.to_s
    rescue URI::InvalidURIError
      nil
    end
    return unless absolute_url

    safe_uri = UrlSafety.safe_uri_for(absolute_url)
    safe_uri&.to_s
  end
end

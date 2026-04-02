# Service for creating feeds from discovery results or suggested feeds
# Encapsulates the feed creation logic to keep controllers thin
class FeedCreatorService
  class Error < StandardError; end

  # Creates or finds a feed from discovery results
  # @param discovery_result [Hash] containing :feed_url and :site_url
  # @return [Feed] the created or found feed
  def self.create_from_discovery(discovery_result)
    feed = Feed.find_or_initialize_by(feed_url: discovery_result[:feed_url])

    if feed.new_record?
      feed.site_url = discovery_result[:site_url]
      fetch_initial_metadata(feed)
      feed.title = extract_host_from_url(feed.feed_url) if feed.title.blank?
      feed.save!
    end

    feed
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("FeedCreatorService: Failed to create feed: #{e.message}")
    raise Error, "Failed to create feed: #{e.message}"
  end

  # Creates or finds a feed from a suggested feed
  # @param suggested_feed [SuggestedFeed] the suggested feed to create from
  # @return [Feed] the created or found feed
  def self.create_from_suggested(suggested_feed)
    feed = Feed.find_or_initialize_by(feed_url: suggested_feed.feed_url)

    if feed.new_record?
      feed.title = suggested_feed.title
      feed.site_url = suggested_feed.site_url
      fetch_initial_metadata(feed)
      feed.title = suggested_feed.title if feed.title.blank? || feed.title == extract_host_from_url(feed.feed_url)
      feed.save!
    end

    feed
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("FeedCreatorService: Failed to create feed from suggested: #{e.message}")
    raise Error, "Failed to create feed: #{e.message}"
  end

  # Fetches initial metadata (title, site_url) for a feed
  # @param feed [Feed] the feed to fetch metadata for
  def self.fetch_initial_metadata(feed)
    FeedFetcherService.new(feed).fetch_metadata
  rescue StandardError => e
    Rails.logger.warn("FeedCreatorService: Could not fetch metadata for #{feed.feed_url}: #{e.message}")
    # Don't raise - we can still create the feed without metadata
  end

  # Extracts the host from a URL for use as a fallback title
  # @param url [String] the URL to extract host from
  # @return [String] the host or "Unknown Feed" if extraction fails
  def self.extract_host_from_url(url)
    URI.parse(url).host || "Unknown Feed"
  rescue URI::InvalidURIError
    "Unknown Feed"
  end
end

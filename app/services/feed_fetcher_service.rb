class FeedFetcherService
  def initialize(feed)
    @feed = feed
  end

  # Fetch only the feed metadata (title, site_url) without creating articles.
  # Only assigns attributes — does not persist. Used before the first full refresh.
  def fetch_metadata
    uri = UrlSafety.safe_uri_for(@feed.feed_url)
    unless uri
      Rails.logger.warn("Feed metadata fetch blocked unsafe URL for feed #{@feed.feed_url}")
      return
    end

    response = HTTParty.get(uri.to_s, timeout: 10)
    parsed_feed = Feedjira.parse(response.body)
    return unless parsed_feed

    @feed.title = parsed_feed.title if parsed_feed.title.present? && @feed.title.blank?
    @feed.site_url = parsed_feed.try(:url) if parsed_feed.try(:url).present? && @feed.site_url.blank?
  rescue => e
    Rails.logger.warn("Feed metadata fetch failed for #{@feed.feed_url}: #{e.message}")
  end

  def fetch
    uri = UrlSafety.safe_uri_for(@feed.feed_url)
    unless uri
      Rails.logger.warn("Feed fetch blocked unsafe URL for feed #{@feed.id}: #{@feed.feed_url}")
      return []
    end

    response = HTTParty.get(uri.to_s, timeout: 15)
    parsed_feed = Feedjira.parse(response.body)

    return [] unless parsed_feed

    # Update feed metadata if available
    update_feed_metadata(parsed_feed)

    # Process each entry
    articles = parsed_feed.entries.map do |entry|
      create_or_update_article(entry)
    end.compact

    # Queue background jobs to fetch full content for articles that need it
    articles.each do |article|
      if ArticleContentFetcherService.needs_fetch?(article)
        ArticleContentFetchJob.perform_later(article.id)
      end
    end

    @feed.update(last_fetched_at: Time.current)
    articles
  rescue => e
    Rails.logger.error("Feed fetch error for #{@feed.feed_url}: #{e.message}")
    []
  end

  private

  def update_feed_metadata(parsed_feed)
    updates = {}
    updates[:title] = parsed_feed.title if parsed_feed.title.present? && @feed.title.blank?
    updates[:site_url] = parsed_feed.url if parsed_feed.url.present? && @feed.site_url.blank?

    @feed.update(updates) if updates.any?
  end

  def create_or_update_article(entry)
    # Generate GUID if not present
    guid = entry.entry_id || entry.url || Digest::SHA256.hexdigest("#{entry.title}#{entry.published}")

    article = @feed.articles.find_or_initialize_by(guid: guid)

    # Only update if this is a new article or content has changed
    if article.new_record? || article_content_changed?(article, entry)
      article.assign_attributes(
        title: entry.title.to_s.strip,
        content: extract_content(entry),
        url: entry.url,
        published_at: entry.published || Time.current
      )

      article.save ? article : nil
    else
      nil
    end
  end

  def article_content_changed?(article, entry)
    new_content = extract_content(entry)
    article.content != new_content
  end

  def extract_content(entry)
    # Try to get the full content from various possible fields
    content = entry.content || entry.summary || entry.description || ""

    # If content is still empty or very short, try other fields
    if content.to_s.strip.length < 100
      content = entry.try(:content_encoded) || content
    end

    # Clean up the content
    clean_content(content.to_s)
  end

  def clean_content(content)
    # First, use Loofah to completely remove dangerous elements and their content
    doc = Loofah.fragment(content.to_s)
    doc.scrub!(:prune) # Removes unsafe elements and their contents entirely

    # Then sanitize to only allow safe formatting tags
    ActionController::Base.helpers.sanitize(
      doc.to_s,
      tags: %w[p br div span strong b em i u a ul ol li blockquote pre code
               h1 h2 h3 h4 h5 h6 img figure figcaption table thead tbody tr th td],
      attributes: %w[href src alt title class]
    ).strip
  end
end

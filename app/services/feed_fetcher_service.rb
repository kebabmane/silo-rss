class FeedFetcherService
  def initialize(feed)
    @feed = feed
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
    # Remove script tags and their content
    content = content.gsub(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/mi, "")

    # Keep the HTML but ensure it's safe
    content.strip
  end
end

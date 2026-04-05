# frozen_string_literal: true

class ArticleContentFetcherService
  def initialize(article)
    @article = article
  end

  def fetch
    return if @article.url.blank?
    uri = UrlSafety.safe_uri_for(@article.url)
    unless uri
      Rails.logger.warn("Content fetch blocked unsafe URL for article #{@article.id}: #{@article.url}")
      return false
    end
    return if @article.full_content.present? # Already fetched

    begin
      response = HTTParty.get(uri.to_s, timeout: 15, follow_redirects: true)
      return false unless response.success?

      # Use Readability to extract the main content
      source = Readability::Document.new(
        response.body,
        tags: %w[div p img a h1 h2 h3 h4 h5 h6 blockquote ul ol li pre code],
        attributes: %w[href src alt],
        remove_empty_nodes: true
      )

      extracted_content = source.content

      # Only save if we got substantial content
      if extracted_content.present? && extracted_content.length > 100
        @article.update(full_content: extracted_content)
        Rails.logger.info("Fetched full content for article #{@article.id}: #{@article.title}")
        true
      else
        Rails.logger.warn("Insufficient content extracted for article #{@article.id}")
        false
      end
    rescue HTTParty::Error, Timeout::Error, SocketError => e
      Rails.logger.error("HTTP error fetching content for #{@article.url}: #{e.message}")
      false
    rescue => e
      Rails.logger.error("Error fetching content for #{@article.url}: #{e.message}")
      false
    end
  end

  # Check if article needs content fetching (short or missing content from RSS)
  def self.needs_fetch?(article)
    return false if article.url.blank?
    return false if article.full_content.present?

    # If RSS content is short (< 500 chars), try to fetch full content
    article.content.to_s.strip.length < 500
  end
end

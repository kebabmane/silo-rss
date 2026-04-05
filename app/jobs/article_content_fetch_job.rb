# frozen_string_literal: true

class ArticleContentFetchJob < ApplicationJob
  queue_as :default

  # Retry on network/content extraction errors with exponential backoff
  retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |_job, error|
    Rails.logger.warn "[ArticleContentFetchJob] Retrying after error: #{error.message}"
  end

  def perform(article_id)
    article = Article.find_by(id: article_id)
    return unless article

    Rails.logger.info "[ArticleContentFetchJob] Fetching full content for: #{article.title} (ID: #{article.id})"

    result = ArticleContentFetcherService.new(article).fetch

    if result
      Rails.logger.info "[ArticleContentFetchJob] Successfully fetched full content for: #{article.title}"
    else
      Rails.logger.warn "[ArticleContentFetchJob] Failed to fetch full content for: #{article.title}"
    end
  end
end

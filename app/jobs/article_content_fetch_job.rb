class ArticleContentFetchJob < ApplicationJob
  queue_as :default

  def perform(article_id)
    article = Article.find_by(id: article_id)
    return unless article

    ArticleContentFetcherService.new(article).fetch
  end
end

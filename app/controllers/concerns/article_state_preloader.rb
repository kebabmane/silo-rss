# frozen_string_literal: true

module ArticleStatePreloader
  extend ActiveSupport::Concern

  private

  def preload_article_states(articles, user)
    # Get article IDs
    article_ids = articles.map(&:id)

    # Load all article states for these articles and this user in one query
    states = ArticleState.where(article_id: article_ids, user_id: user.id).to_a

    # Create a hash for quick lookup
    states_by_article_id = states.index_by(&:article_id)

    # Preload the states into the articles association
    articles.each do |article|
      state = states_by_article_id[article.id]
      article.association(:article_states).target = state ? [ state ] : []
      article.association(:article_states).loaded!
    end
  end
end

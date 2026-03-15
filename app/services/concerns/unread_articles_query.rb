module UnreadArticlesQuery
  private

  def fetch_unread_articles
    feeds = @schedule.feeds_to_include
    feed_ids = feeds.map(&:id)

    Article
      .includes(:feed)
      .left_joins(:article_states)
      .where(feed_id: feed_ids)
      .where("articles.published_at >= ?", 24.hours.ago)
      .where("article_states.id IS NULL OR (article_states.user_id = ? AND article_states.read = ?)", @user.id, false)
      .order(published_at: :desc)
      .limit(100)
  end
end

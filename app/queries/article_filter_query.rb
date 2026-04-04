# Query object for filtering articles in the dashboard
# Encapsulates the complex filtering logic to keep controllers thin
class ArticleFilterQuery
  def initialize(user:, feed_id: nil, category: nil, filter: "unread")
    @user = user
    @feed_id = feed_id
    @category = category
    @filter = filter
  end

  # Builds and returns the filtered article query
  # @return [ActiveRecord::Relation] the filtered articles relation
  def call
    articles_query = base_query
    articles_query = apply_feed_filter(articles_query)
    articles_query = apply_category_filter(articles_query)
    articles_query = apply_status_filter(articles_query)
    articles_query
  end

  private

  def base_query
    Article.joins(feed: :subscriptions)
           .where(subscriptions: { user_id: @user.id })
           .includes(:feed)
           .recent
  end

  def apply_feed_filter(query)
    return query unless @feed_id.present?
    query.where(feed_id: @feed_id)
  end

  def apply_category_filter(query)
    return query unless @category.present?
    query.where(subscriptions: { category: @category })
  end

  def apply_status_filter(query)
    case @filter
    when "unread"
      query.unread_for(@user)
    when "starred"
      query.starred_for(@user).all_unarchived_for(@user)
    when "archived"
      query.archived_for(@user)
    else
      query.all_unarchived_for(@user)
    end
  end
end

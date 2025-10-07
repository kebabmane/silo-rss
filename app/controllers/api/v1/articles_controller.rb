module Api
  module V1
    class ArticlesController < BaseController
      before_action :set_article, only: [:mark_read, :mark_starred, :mark_archived]

      # GET /api/v1/articles
      def index
        articles = Article.joins(feed: :subscriptions)
                         .where(subscriptions: { user_id: current_user.id })
                         .includes(:feed)
                         .recent

        # Apply filters
        articles = articles.where(feed_id: params[:feed_id]) if params[:feed_id].present?

        if params[:category].present?
          # Avoid duplicate joins - already joined above
          articles = articles.where(subscriptions: { category: params[:category] })
        end

        if params[:filter] == 'unread'
          articles = articles.left_joins(:article_states)
                           .where("article_states.id IS NULL OR (article_states.user_id = ? AND article_states.read = ?)", current_user.id, false)
        elsif params[:filter] == 'starred'
          articles = articles.joins(:article_states)
                           .where(article_states: { user_id: current_user.id, starred: true })
        elsif params[:filter] == 'archived'
          articles = articles.joins(:article_states)
                           .where(article_states: { user_id: current_user.id, archived: true })
        else
          # Exclude archived by default
          articles = articles.left_joins(:article_states)
                           .where("article_states.id IS NULL OR (article_states.user_id = ? AND article_states.archived = ?)", current_user.id, false)
        end

        # Get total count before limiting
        total_count = articles.count(:all)

        articles = articles.limit(params[:limit] || 50).offset(params[:offset] || 0)

        # Preload article states for current user
        preload_article_states(articles, current_user)

        # Enable ETag caching for mobile apps
        fresh_when(etag: [articles, current_user], last_modified: articles.maximum(:updated_at), public: false)

        render json: {
          articles: articles.map { |article|
            state = article.article_states.first || ArticleState.new(read: false, starred: false, archived: false)
            {
              id: article.id,
              title: article.title,
              content: article.content&.truncate(300, omission: '...'), # Truncate for mobile bandwidth
              url: article.url,
              published_at: article.published_at,
              feed: {
                id: article.feed.id,
                title: article.feed.title
              },
              state: {
                read: state.read,
                starred: state.starred,
                archived: state.archived
              }
            }
          },
          meta: {
            total: total_count,
            limit: params[:limit] || 50,
            offset: params[:offset] || 0
          }
        }
      end

      # GET /api/v1/articles/:id
      def show
        article = Article.joins(feed: :subscriptions)
                        .where(subscriptions: { user_id: current_user.id })
                        .includes(:feed)
                        .find(params[:id])

        state = article.state_for(current_user)

        render json: {
          article: {
            id: article.id,
            title: article.title,
            content: article.content,
            url: article.url,
            published_at: article.published_at,
            feed: {
              id: article.feed.id,
              title: article.feed.title,
              site_url: article.feed.site_url
            },
            state: {
              read: state.read,
              starred: state.starred,
              archived: state.archived
            }
          }
        }
      end

      # PATCH /api/v1/articles/:id/read
      def mark_read
        state = @article.state_for(current_user)
        state.update(read: params[:read])

        render json: { state: { read: state.read } }
      end

      # PATCH /api/v1/articles/:id/star
      def mark_starred
        state = @article.state_for(current_user)
        state.update(starred: params[:starred])

        render json: { state: { starred: state.starred } }
      end

      # PATCH /api/v1/articles/:id/archive
      def mark_archived
        state = @article.state_for(current_user)
        state.update(archived: params[:archived])

        render json: { state: { archived: state.archived } }
      end

      # GET /api/v1/articles/search
      def search
        query = params[:q]
        # Sanitize query for LIKE to prevent SQL injection
        sanitized_query = query.to_s.gsub(/[\\%_]/) { |x| "\\#{x}" }

        articles = Article.joins(feed: :subscriptions)
                         .where(subscriptions: { user_id: current_user.id })
                         .where("articles.title LIKE ? OR articles.content LIKE ?", "%#{sanitized_query}%", "%#{sanitized_query}%")
                         .includes(:feed)
                         .recent
                         .limit(50)

        # Preload article states for current user
        preload_article_states(articles, current_user)

        render json: {
          articles: articles.map { |article|
            state = article.article_states.first || ArticleState.new(read: false, starred: false, archived: false)
            {
              id: article.id,
              title: article.title,
              content: article.content&.truncate(200, omission: '...'), # Safe truncation
              url: article.url,
              published_at: article.published_at,
              feed: {
                id: article.feed.id,
                title: article.feed.title
              },
              state: {
                read: state.read,
                starred: state.starred,
                archived: state.archived
              }
            }
          }
        }
      end

      # GET /api/v1/articles/unread_count
      def unread_count
        count = Article.joins(feed: :subscriptions)
                      .where(subscriptions: { user_id: current_user.id })
                      .left_joins(:article_states)
                      .where("article_states.id IS NULL OR (article_states.user_id = ? AND article_states.read = ? AND article_states.archived = ?)", current_user.id, false, false)
                      .count

        render json: { unread_count: count }
      end

      # POST /api/v1/articles/batch_update
      def batch_update
        article_ids = Array(params[:article_ids])
        action_name = params[:bulk_action] || params[:operation]
        value = ActiveModel::Type::Boolean.new.cast(params[:value])

        if article_ids.empty?
          render json: { error: 'No article IDs provided' }, status: :unprocessable_entity
          return
        end

        unless %w[mark_read mark_starred mark_archived].include?(action_name)
          render json: { error: 'Invalid action' }, status: :unprocessable_entity
          return
        end

        articles = Article.joins(feed: :subscriptions)
                         .where(subscriptions: { user_id: current_user.id })
                         .where(id: article_ids)

        case action_name
        when 'mark_read'
          articles.each do |article|
            state = article.state_for(current_user)
            state.update(read: value)
          end
        when 'mark_starred'
          articles.each do |article|
            state = article.state_for(current_user)
            state.update(starred: value)
          end
        when 'mark_archived'
          articles.each do |article|
            state = article.state_for(current_user)
            state.update(archived: value)
          end
        render json: { success: true, updated_count: articles.count }
      end

      # POST /api/v1/articles/mark_all_read
      def mark_all_read
        feed_id = params[:feed_id]
        category = params[:category]

        articles = Article.joins(feed: :subscriptions)
                         .where(subscriptions: { user_id: current_user.id })

        articles = articles.where(feed_id: feed_id) if feed_id.present?
        articles = articles.joins(feed: :subscriptions)
                          .where(subscriptions: { category: category, user_id: current_user.id }) if category.present?

        count = 0
        articles.each do |article|
          state = article.state_for(current_user)
          state.update(read: true) unless state.read
          count += 1
        end

        render json: { success: true, marked_count: count }
      end

      private

      def set_article
        @article = Article
          .joins(feed: :subscriptions)
          .where(subscriptions: { user_id: current_user.id })
          .find_by(id: params[:id])

        return if @article

        render json: { error: 'Not Found' }, status: :not_found
        return
      end

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
          article.association(:article_states).target = state ? [state] : []
          article.association(:article_states).loaded!
        end
      end
    end
  end
end

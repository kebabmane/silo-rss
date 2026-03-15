module Api
  module V1
    class ArticlesController < BaseController
      include ArticleStatePreloader

      before_action :set_article, only: [:mark_read, :mark_starred, :mark_archived]

      # GET /api/v1/articles
      def index
        articles = Article.for_user(current_user)
                         .includes(:feed)
                         .recent

        limit = params[:limit].present? ? params[:limit].to_i : 50
        limit = 50 if limit <= 0
        offset = params[:offset].present? ? params[:offset].to_i : 0
        offset = 0 if offset.negative?

        # Apply filters
        articles = articles.where(feed_id: params[:feed_id]) if params[:feed_id].present?

        if params[:category].present?
          articles = articles.where(subscriptions: { category: params[:category] })
        end

        if params[:filter] == 'unread'
          articles = articles.unread_for(current_user)
        elsif params[:filter] == 'starred'
          articles = articles.starred_for(current_user).all_unarchived_for(current_user)
        elsif params[:filter] == 'archived'
          articles = articles.archived_for(current_user)
        else
          # Exclude archived by default
          articles = articles.all_unarchived_for(current_user)
        end

        # Get total count before limiting
        total_count = articles.count(:all)

        articles = articles.limit(limit).offset(offset)

        # Preload article states for current user
        preload_article_states(articles, current_user)

        # Enable ETag caching for mobile apps
        fresh_when(etag: [articles, current_user], last_modified: articles.maximum(:updated_at), public: false)

        render json: {
          articles: articles.map { |article|
            state = article.article_states.first || ArticleState.new(read: false, starred: false, archived: false)
            Api::V1::ArticleSerializer.new(article, state: state).as_summary
          },
          meta: {
            total: total_count,
            limit: limit,
            offset: offset
          }
        }
      end

      # GET /api/v1/articles/:id
      def show
        article = Article.for_user(current_user)
                        .includes(:feed)
                        .find(params[:id])

        state = article.state_for(current_user)

        render json: {
          article: Api::V1::ArticleSerializer.new(article, state: state).as_detail
        }
      end

      # PATCH /api/v1/articles/:id/read
      def mark_read
        state = @article.state_for(current_user)
        state.update(read: params[:read])

        render json: {
          state: Api::V1::ArticleSerializer.new(@article, state: state).state_hash
        }
      end

      # PATCH /api/v1/articles/:id/star
      def mark_starred
        state = @article.state_for(current_user)
        state.update(starred: params[:starred])

        render json: {
          state: Api::V1::ArticleSerializer.new(@article, state: state).state_hash
        }
      end

      # PATCH /api/v1/articles/:id/archive
      def mark_archived
        state = @article.state_for(current_user)
        state.update(archived: params[:archived])

        render json: {
          state: Api::V1::ArticleSerializer.new(@article, state: state).state_hash
        }
      end

      # GET /api/v1/articles/search
      def search
        query = params[:q]
        return render(json: { articles: [] }) if query.blank?

        articles = Article.for_user(current_user)
                         .search_text(query)
                         .includes(:feed)
                         .recent
                         .limit(50)

        # Preload article states for current user
        preload_article_states(articles, current_user)

        render json: {
          articles: articles.map { |article|
            state = article.article_states.first || ArticleState.new(read: false, starred: false, archived: false)
            Api::V1::ArticleSerializer.new(article, state: state).as_search_result
          }
        }
      end

      # GET /api/v1/articles/unread_count
      def unread_count
        count = Article.for_user(current_user)
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

        # Only update articles the user is subscribed to
        valid_ids = Article.for_user(current_user)
                          .where(id: article_ids)
                          .pluck(:id)

        attribute = case action_name
                    when 'mark_read' then :read
                    when 'mark_starred' then :starred
                    when 'mark_archived' then :archived
                    end

        ArticleState.bulk_set(
          user: current_user,
          article_ids: valid_ids,
          attribute: attribute,
          value: value
        )

        render json: { success: true, updated_count: valid_ids.size }
      end

      # POST /api/v1/articles/mark_all_read
      def mark_all_read
        feed_id = params[:feed_id]
        category = params[:category]

        articles = Article.for_user(current_user)

        articles = articles.where(feed_id: feed_id) if feed_id.present?
        if category.present?
          articles = articles.where(subscriptions: { category: category })
        end

        article_ids = articles.pluck(:id)

        ArticleState.bulk_set(
          user: current_user,
          article_ids: article_ids,
          attribute: :read,
          value: true
        )

        render json: { success: true, marked_count: article_ids.size }
      end

      private

      def set_article
        @article = Article.for_user(current_user)
          .find_by(id: params[:id])

        return if @article

        render json: { error: 'Not Found' }, status: :not_found
        return
      end
    end
  end
end

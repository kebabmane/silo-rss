module Api
  module V1
    class SyncController < BaseController
      # GET /api/v1/sync
      # Delta sync endpoint for mobile apps
      # Returns changes since the provided timestamp
      def index
        since_time = parse_since_param

        # Get articles changed since timestamp
        articles = Article.for_user(current_user)
                         .includes(:feed, :article_states)
                         .sync_since(since_time)
                         .recent
                         .limit(500)

        # Get feeds changed since timestamp
        feeds = Feed.for_user(current_user)
                    .sync_since(since_time)
                    .includes(:subscriptions)

        # Get article states changed since timestamp
        states = ArticleState.for_user(current_user)
                             .sync_since(since_time)
                             .includes(:article)
                             .limit(1000)

        # Get deleted/subscription changes (feeds user unsubscribed from)
        recently_unsubscribed = Subscription.where(user_id: current_user.id)
                                          .where("updated_at > ?", since_time)
                                          .where(unsubscribed_at: since_time..)
                                          .pluck(:feed_id)

        render json: {
          sync_meta: {
            synced_at: Time.current.iso8601,
            since: since_time&.iso8601,
            has_more: articles.size >= 500
          },
          articles: {
            added: articles.map { |a| serialize_article(a, :summary) },
            updated: articles.map { |a| serialize_article(a, :summary) }
          },
          feeds: {
            added: feeds.map { |f| serialize_feed(f) },
            updated: feeds.map { |f| serialize_feed(f) },
            deleted: recently_unsubscribed
          },
          states: states.map { |s| serialize_state(s) }
        }
      end

      # GET /api/v1/sync/status
      # Quick status check for unread counts, total articles
      def status
        unread_count = Article.for_user(current_user)
                              .left_joins(:article_states)
                              .where("article_states.id IS NULL OR (article_states.user_id = ? AND article_states.read = ? AND article_states.archived = ?)", current_user.id, false, false)
                              .count

        total_articles = Article.for_user(current_user)
                                .left_joins(:article_states)
                                .where("article_states.id IS NULL OR (article_states.user_id = ? AND article_states.archived = ?)", current_user.id, false)
                                .count

        starred_count = Article.for_user(current_user)
                               .joins(:article_states)
                               .where(article_states: { user_id: current_user.id, starred: true, archived: false })
                               .count

        feeds_count = current_user.subscriptions.count

        last_sync_time = params[:since].present? ? Time.parse(params[:since]) : nil

        # Check if there are new articles since last sync
        has_updates = if last_sync_time
          Article.for_user(current_user)
                 .where("articles.created_at > ?", last_sync_time)
                 .exists?
        else
          true
        end

        render json: {
          unread_count: unread_count,
          total_articles: total_articles,
          starred_count: starred_count,
          feeds_count: feeds_count,
          has_updates: has_updates,
          last_sync_at: Time.current.iso8601
        }
      end

      private

      def parse_since_param
        return nil if params[:since].blank?

        Time.parse(params[:since])
      rescue ArgumentError
        nil
      end

      def serialize_article(article, format = :summary)
        state = article.article_states.detect { |s| s.user_id == current_user.id } ||
                ArticleState.new(read: false, starred: false, archived: false)

        ArticleSerializer.new(article, state: state).as_summary
      end

      def serialize_feed(feed)
        subscription = feed.subscriptions.find_by(user_id: current_user.id)

        {
          id: feed.id,
          title: feed.title,
          feed_url: feed.feed_url,
          site_url: feed.site_url,
          last_fetched_at: feed.last_fetched_at,
          category: subscription&.category,
          custom_name: subscription&.custom_name,
          unread_count: Article.where(feed: feed)
                               .for_user(current_user)
                               .left_joins(:article_states)
                               .where("article_states.id IS NULL OR (article_states.read = ? AND article_states.archived = ?)", false, false)
                               .count
        }
      end

      def serialize_state(state)
        {
          article_id: state.article_id,
          read: state.read,
          starred: state.starred,
          archived: state.archived,
          updated_at: state.updated_at.iso8601
        }
      end
    end
  end
end

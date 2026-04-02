module Api
  module V1
    class ArticleSerializer
      attr_reader :article, :state

      def initialize(article, state: nil)
        @article = article
        @state = state || ArticleState.new(read: false, starred: false, archived: false)
      end

      def as_summary
        {
          id: article.id,
          title: article.title,
          content: article.content&.truncate(300, omission: '...'),
          url: article.url,
          published_at: article.published_at,
          feed: feed_hash,
          state: state_hash
        }
      end

      def as_search_result
        {
          id: article.id,
          title: article.title,
          content: article.content&.truncate(200, omission: '...'),
          url: article.url,
          published_at: article.published_at,
          feed: feed_hash,
          state: state_hash
        }
      end

      def as_detail
        {
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
          state: state_hash
        }
      end

      def state_hash
        {
          read: state.read,
          starred: state.starred,
          archived: state.archived
        }
      end

      private

      def feed_hash
        {
          id: article.feed.id,
          title: article.feed.title
        }
      end
    end
  end
end

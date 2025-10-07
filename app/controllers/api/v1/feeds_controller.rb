module Api
  module V1
    class FeedsController < BaseController
      # GET /api/v1/feeds - returns user's subscriptions
      def index
        subscriptions = current_user.subscriptions.includes(:feed)
        render json: subscriptions.map { |sub|
          {
            id: sub.id,
            category: sub.category,
            custom_name: sub.custom_name,
            feed: {
              id: sub.feed.id,
              title: sub.feed.title,
              feed_url: sub.feed.feed_url,
              site_url: sub.feed.site_url,
              last_fetched_at: sub.feed.last_fetched_at
            }
          }
        }
      end

      # GET /api/v1/feeds/browse - returns all available feeds in the system
      def browse
        feeds = Feed.all.order(created_at: :desc).limit(100)
        render json: feeds.map { |feed|
          {
            id: feed.id,
            title: feed.title,
            feed_url: feed.feed_url,
            site_url: feed.site_url,
            last_fetched_at: feed.last_fetched_at
          }
        }
      end

      # POST /api/v1/feeds/discover
      def discover
        discovery_result = FeedDiscoveryService.new(params[:url]).discover

        if discovery_result
          feed = Feed.find_or_create_by(feed_url: discovery_result[:feed_url]) do |f|
            f.site_url = discovery_result[:site_url]

            # Fetch metadata
            parsed_feed = Feedjira.parse(HTTParty.get(f.feed_url).body)
            f.title = parsed_feed.title if parsed_feed
          end

          render json: {
            feed: {
              id: feed.id,
              title: feed.title,
              feed_url: feed.feed_url,
              site_url: feed.site_url
            }
          }, status: :ok
        else
          render json: { error: 'Feed not found' }, status: :not_found
        end
      end

      # POST /api/v1/feeds
      def create
        feed = Feed.find(params[:feed_id])
        subscription = current_user.subscriptions.build(
          feed: feed,
          category: params[:category],
          custom_name: params[:custom_name]
        )

        if subscription.save
          # Trigger background fetch
          FeedRefreshJob.perform_later(feed.id)

          render json: {
            subscription: {
              id: subscription.id,
              category: subscription.category,
              custom_name: subscription.custom_name,
              feed: {
                id: feed.id,
                title: feed.title,
                feed_url: feed.feed_url,
                site_url: feed.site_url
              }
            }
          }, status: :created
        else
          render json: { error: subscription.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/feeds/:id
      def destroy
        subscription = current_user.subscriptions.find_by(feed_id: params[:id])

        if subscription
          subscription.destroy
          head :no_content
        else
          render json: { error: 'Subscription not found' }, status: :not_found
        end
      end
    end
  end
end

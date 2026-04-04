module Api
  module V1
    class IconsController < BaseController
      # GET /api/v1/feeds/:feed_id/icon
      # Proxy and cache feed favicons
      def feed_icon
        feed = Feed.find_by(id: params[:feed_id])

        unless feed
          return render json: { error: "Feed not found" }, status: :not_found
        end

        # Check if user is subscribed to this feed
        unless current_user.feeds.exists?(id: feed.id)
          return render json: { error: "Unauthorized" }, status: :unauthorized
        end

        # Try to fetch the icon
        icon_url = fetch_favicon(feed.site_url)

        if icon_url
          redirect_to icon_url, allow_other_host: true
        else
          # Return a default icon
          redirect_to ActionController::Base.helpers.image_url("default-feed-icon.png")
        end
      end

      private

      def fetch_favicon(site_url)
        return nil if site_url.blank?

        uri = URI.parse(site_url)
        base_url = "#{uri.scheme}://#{uri.host}"

        # Common favicon locations
        favicon_paths = [
          "/favicon.ico",
          "/favicon.png",
          "/apple-touch-icon.png",
          "/apple-touch-icon-precomposed.png"
        ]

        # Try to fetch the page and look for icon link
        begin
          response = HTTParty.get(site_url, timeout: 5)
          doc = Nokogiri::HTML(response.body)

          # Look for icon in link tags
          icon_link = doc.at_css('link[rel~="icon"]') ||
                     doc.at_css('link[rel="shortcut icon"]') ||
                     doc.at_css('link[rel="apple-touch-icon"]')

          if icon_link && icon_link["href"].present?
            href = icon_link["href"]
            return URI.join(base_url, href).to_s if href.present?
          end
        rescue StandardError
          # Fall through to trying common paths
        end

        # Try common favicon locations
        favicon_paths.each do |path|
          url = "#{base_url}#{path}"
          begin
            response = HTTParty.head(url, timeout: 3)
            return url if response.code == 200
          rescue StandardError
            next
          end
        end

        nil
      rescue URI::InvalidURIError
        nil
      end
    end
  end
end

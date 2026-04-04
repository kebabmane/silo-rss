class OpmlService
  def self.export(user)
    builder = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
      xml.opml(version: "2.0") {
        xml.head {
          xml.title "Silo Export"
          xml.dateCreated Time.current.rfc2822
        }
        xml.body {
          # Group by category
          user.subscriptions.group_by(&:category).each do |category, subscriptions|
            xml.outline(text: category, title: category) {
              subscriptions.each do |subscription|
                xml.outline(
                  type: "rss",
                  text: subscription.display_name,
                  title: subscription.display_name,
                  xmlUrl: subscription.feed.feed_url,
                  htmlUrl: subscription.feed.site_url
                )
              end
            }
          end
        }
      }
    end
    builder.to_xml
  end

  def self.import(user, opml_file)
    doc = Nokogiri::XML(opml_file.read)
    imported_count = 0

    # Find all outline elements with xmlUrl (feed entries)
    doc.xpath("//outline[@xmlUrl]").each do |outline|
      feed_url = outline["xmlUrl"]
      category = outline.parent["text"] || outline.parent["title"] || "Imported"
      custom_name = outline["text"] || outline["title"]

      begin
        # Find or create feed
        feed = Feed.find_by(feed_url: feed_url)
        is_new_feed = feed.nil?

        # If no title is provided, use the feed URL as a fallback
        feed_title = custom_name.presence || feed_url

        feed ||= Feed.create!(
          feed_url: feed_url,
          title: feed_title,
          site_url: outline["htmlUrl"]
        )

        # Create subscription if it doesn't exist
        unless user.subscriptions.exists?(feed: feed)
          # Only set custom_name if it differs from feed title, or if this is a new feed we just created
          subscription_custom_name = if is_new_feed || custom_name != feed.title
                                       custom_name
          end

          user.subscriptions.create!(
            feed: feed,
            category: category,
            custom_name: subscription_custom_name
          )

          # Fetch initial articles
          FeedRefreshJob.perform_later(feed.id)
          imported_count += 1
        end
      rescue => e
        Rails.logger.error("Failed to import feed #{feed_url}: #{e.message}")
      end
    end

    imported_count
  end
end

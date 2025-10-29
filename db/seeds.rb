# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Seed default suggested feeds
default_feeds = [
  # News
  { title: "BBC News", feed_url: "http://feeds.bbc.co.uk/news/rss.xml", category: "News", description: "BBC World News", display_order: 1 },
  { title: "Reuters", feed_url: "https://www.reutersagency.com/feed/?taxonomy=best-topics&output=rss", category: "News", description: "Reuters News Agency", display_order: 2 },
  { title: "The Guardian", feed_url: "https://www.theguardian.com/international/rss", category: "News", description: "The Guardian World News", display_order: 3 },

  # Technology
  { title: "Hacker News", feed_url: "https://news.ycombinator.com/rss", category: "Technology", description: "Hacker News - Interesting tech news", display_order: 1 },
  { title: "TechCrunch", feed_url: "https://techcrunch.com/feed/", category: "Technology", description: "Technology news and analysis", display_order: 2 },
  { title: "The Verge", feed_url: "https://www.theverge.com/rss/index.xml", category: "Technology", description: "Tech news, reviews, and features", display_order: 3 },

  # Business
  { title: "Financial Times", feed_url: "https://feeds.ft.com/home/homepage", category: "Business", description: "FT.com homepage news", display_order: 1 },
  { title: "Bloomberg", feed_url: "https://www.bloomberg.com/feed/podcast/etf-report.rss", category: "Business", description: "Bloomberg Business News", display_order: 2 },

  # Science
  { title: "Nature", feed_url: "http://feeds.nature.com/nature/rss/current", category: "Science", description: "Latest scientific research", display_order: 1 },
  { title: "Science Daily", feed_url: "https://www.sciencedaily.com/rss/all.xml", category: "Science", description: "Science News & Research", display_order: 2 },

  # Entertainment
  { title: "Variety", feed_url: "https://variety.com/feed/", category: "Entertainment", description: "Entertainment news and reviews", display_order: 1 },
  { title: "Deadline", feed_url: "https://deadline.com/feed/", category: "Entertainment", description: "Entertainment industry news", display_order: 2 },
]

default_feeds.each do |feed|
  SuggestedFeed.find_or_create_by!(feed_url: feed[:feed_url]) do |suggested_feed|
    suggested_feed.title = feed[:title]
    suggested_feed.category = feed[:category]
    suggested_feed.description = feed[:description]
    suggested_feed.display_order = feed[:display_order]
  end
end

puts "Seeded #{SuggestedFeed.count} suggested feeds"

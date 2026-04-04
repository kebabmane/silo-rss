# frozen_string_literal: true

require "thor"
require "httparty"
require "json"
require "yaml"
require "fileutils"

module Silo
  class CLI < Thor
    include Thor::Actions

    SILO_DIR = File.expand_path("~/.silo").freeze
    CONFIG_FILE = File.join(SILO_DIR, "config.yml").freeze
    DEFAULT_API_URL = "http://localhost:3000/api/v1"

    desc "auth COMMAND", "Authentication commands (login, logout, status)"
    subcommand "auth", AuthCommands

    desc "feeds COMMAND", "Feed management commands (list, add, remove)"
    subcommand "feeds", FeedCommands

    desc "articles COMMAND", "Article commands (list, read, search)"
    subcommand "articles", ArticleCommands

    desc "sync", "Sync articles with the server"
    def sync
      ensure_configured!

      since = config["last_sync_at"]
      url = "#{api_url}/sync"
      url += "?since=#{CGI.escape(since)}" if since

      response = api_get(url)

      if response.success?
        data = JSON.parse(response.body)

        puts "Synced at: #{data["sync_meta"]["synced_at"]}"
        puts "Articles: #{data["articles"]["added"].length} added/updated"
        puts "Feeds: #{data["feeds"]["added"].length} added/updated"
        puts "Has more: #{data["sync_meta"]["has_more"]}"

        # Save sync time
        config["last_sync_at"] = data["sync_meta"]["synced_at"]
        save_config
      else
        error "Sync failed: #{response.code}"
      end
    end

    desc "config", "Show current configuration"
    def config
      ensure_configured!

      puts "API URL: #{api_url}"
      puts "Token: #{config["token"] ? "#{config["token"][0..10]}..." : "Not set"}"
      puts "Last sync: #{config["last_sync_at"] || "Never"}"
    end

    desc "mcp", "Start MCP server for AI agent integration"
    def mcp
      ensure_configured!
      require_relative "mcp_server"
      MCPServer.new(config).start
    end

    private

    def api_url
      config["api_url"] || DEFAULT_API_URL
    end

    def config
      @config ||= load_config
    end

    def load_config
      if File.exist?(CONFIG_FILE)
        YAML.safe_load(File.read(CONFIG_FILE), permitted_classes: [ Time, Date ]) || {}
      else
        {}
      end
    end

    def save_config
      FileUtils.mkdir_p(SILO_DIR)
      File.write(CONFIG_FILE, config.to_yaml)
    end

    def ensure_configured!
      unless config["token"]
        error "Not authenticated. Run: silo auth login"
        exit 1
      end
    end

    def api_get(url, options = {})
      headers = {
        "Authorization" => config["token"],
        "Accept" => "application/json"
      }
      HTTParty.get(url, headers: headers, **options)
    end

    def api_post(url, body = {}, options = {})
      headers = {
        "Authorization" => config["token"],
        "Content-Type" => "application/json",
        "Accept" => "application/json"
      }
      HTTParty.post(url, body: body.to_json, headers: headers, **options)
    end

    def api_patch(url, body = {}, options = {})
      headers = {
        "Authorization" => config["token"],
        "Content-Type" => "application/json",
        "Accept" => "application/json"
      }
      HTTParty.patch(url, body: body.to_json, headers: headers, **options)
    end

    def api_delete(url, options = {})
      headers = {
        "Authorization" => config["token"],
        "Accept" => "application/json"
      }
      HTTParty.delete(url, headers: headers, **options)
    end
  end

  class AuthCommands < Thor
    desc "login", "Authenticate with Silo server"
    option :email, type: :string, desc: "Email address"
    option :password, type: :string, desc: "Password (will prompt if not provided)"
    option :api_url, type: :string, desc: "API URL (defaults to http://localhost:3000/api/v1)"
    def login
      email = options[:email] || ask("Email:")
      password = options[:password] || ask("Password:", echo: false)
      api_url = options[:api_url] || "http://localhost:3000/api/v1"

      say "Authenticating..."

      response = HTTParty.post(
        "#{api_url}/auth/login",
        body: { email: email, password: password }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

      if response.success?
        data = JSON.parse(response.body)
        token = data["user"]["api_token"]

        # Save config
        config = {
          "api_url" => api_url,
          "token" => token,
          "email" => email
        }

        FileUtils.mkdir_p(Silo::CLI::SILO_DIR)
        File.write(Silo::CLI::CONFIG_FILE, config.to_yaml)

        say "Authenticated successfully!", :green
        say "Token expires at: #{data["user"]["api_token_expires_at"]}"
        say "To generate a non-expiring CLI token, run: silo auth cli_token"
      else
        error "Authentication failed: #{response.code}"
        exit 1
      end
    end

    desc "logout", "Remove authentication"
    def logout
      if File.exist?(Silo::CLI::CONFIG_FILE)
        File.delete(Silo::CLI::CONFIG_FILE)
        say "Logged out successfully", :green
      else
        say "Not logged in"
      end
    end

    desc "status", "Check authentication status"
    def status
      config = load_config

      if config["token"]
        say "Logged in as: #{config["email"] || "Unknown"}"
        say "API URL: #{config["api_url"] || "Default"}"

        # Check token validity
        response = HTTParty.get(
          "#{config["api_url"] || "http://localhost:3000/api/v1"}/profile",
          headers: { "Authorization" => config["token"] }
        )

        if response.success?
          say "Token: Valid", :green
        else
          say "Token: Invalid or expired (#{response.code})", :red
        end
      else
        say "Not logged in", :yellow
      end
    end

    desc "cli_token", "Generate a non-expiring CLI token"
    def cli_token
      config = load_config

      unless config["token"]
        error "Not authenticated. Run: silo auth login"
        exit 1
      end

      response = HTTParty.post(
        "#{config["api_url"] || "http://localhost:3000/api/v1"}/auth/cli_token",
        headers: { "Authorization" => config["token"] }
      )

      if response.success?
        data = JSON.parse(response.body)
        say "CLI Token generated:", :green
        say data["cli_token"]
        say ""
        say "This token does not expire. Store it securely."
        say "Use it with: export SILO_TOKEN=#{data["cli_token"]}"
      else
        error "Failed to generate CLI token: #{response.code}"
        exit 1
      end
    end

    private

    def load_config
      if File.exist?(Silo::CLI::CONFIG_FILE)
        YAML.safe_load(File.read(Silo::CLI::CONFIG_FILE), permitted_classes: [ Time, Date ]) || {}
      else
        {}
      end
    end
  end

  class FeedCommands < Thor
    desc "list", "List subscribed feeds"
    option :format, type: :string, default: "table", enum: %w[table json], desc: "Output format"
    def list
      config = load_config
      ensure_configured!(config)

      response = HTTParty.get(
        "#{config["api_url"] || "http://localhost:3000/api/v1"}/feeds",
        headers: { "Authorization" => config["token"] }
      )

      if response.success?
        data = JSON.parse(response.body)
        feeds = data["feeds"]

        if feeds.empty?
          say "No feeds subscribed"
          return
        end

        case options[:format]
        when "json"
          puts JSON.pretty_generate(feeds)
        else
          say "#{feeds.length} feeds:"
          say ""

          feeds.each do |feed|
            category = feed["category"] ? "[#{feed["category"]}] " : ""
            name = feed["custom_name"] || feed["feed"]["title"]
            unread = feed["unread_count"] || 0

            say "#{feed["id"]}. #{category}#{name} (#{unread} unread)"
            say "   #{feed["feed"]["feed_url"]}"
            say ""
          end
        end
      else
        error "Failed to fetch feeds: #{response.code}"
        exit 1
      end
    end

    desc "add URL", "Subscribe to a new feed"
    option :category, type: :string, desc: "Category for the feed"
    option :name, type: :string, desc: "Custom display name"
    def add(url)
      config = load_config
      ensure_configured!(config)

      api_url = config["api_url"] || "http://localhost:3000/api/v1"

      # First, discover the feed
      say "Discovering feed..."
      discover_response = HTTParty.post(
        "#{api_url}/feeds/discover",
        body: { url: url }.to_json,
        headers: {
          "Authorization" => config["token"],
          "Content-Type" => "application/json"
        }
      )

      unless discover_response.success?
        error "Failed to discover feed: #{discover_response.code}"
        exit 1
      end

      # The feed is created by discover, we need to subscribe to it
      # Extract feed ID from the response
      feed_data = JSON.parse(discover_response.body)
      feed_id = feed_data["feed_id"] || feed_data["feed"]&.[]("id")

      unless feed_id
        error "Could not extract feed ID from discovery response"
        exit 1
      end

      say "Found feed. Subscribing..."

      # Subscribe
      subscribe_response = HTTParty.post(
        "#{api_url}/feeds",
        body: {
          feed_id: feed_id,
          category: options[:category],
          custom_name: options[:name]
        }.to_json,
        headers: {
          "Authorization" => config["token"],
          "Content-Type" => "application/json"
        }
      )

      if subscribe_response.success? || subscribe_response.code == 201
        say "Subscribed successfully!", :green
      else
        error "Failed to subscribe: #{subscribe_response.code}"
        exit 1
      end
    end

    desc "remove FEED_ID", "Unsubscribe from a feed"
    def remove(feed_id)
      config = load_config
      ensure_configured!(config)

      response = HTTParty.delete(
        "#{config["api_url"] || "http://localhost:3000/api/v1"}/feeds/#{feed_id}",
        headers: { "Authorization" => config["token"] }
      )

      if response.success? || response.code == 204
        say "Unsubscribed successfully", :green
      else
        error "Failed to remove feed: #{response.code}"
        exit 1
      end
    end

    desc "sync", "Trigger background sync for all feeds"
    def sync
      config = load_config
      ensure_configured!(config)

      response = HTTParty.post(
        "#{config["api_url"] || "http://localhost:3000/api/v1"}/feeds/sync",
        headers: { "Authorization" => config["token"] }
      )

      if response.success?
        say "Sync triggered successfully", :green
      else
        error "Failed to trigger sync: #{response.code}"
        exit 1
      end
    end

    private

    def load_config
      if File.exist?(Silo::CLI::CONFIG_FILE)
        YAML.safe_load(File.read(Silo::CLI::CONFIG_FILE), permitted_classes: [ Time, Date ]) || {}
      else
        {}
      end
    end

    def ensure_configured!(config)
      unless config["token"]
        error "Not authenticated. Run: silo auth login"
        exit 1
      end
    end
  end

  class ArticleCommands < Thor
    desc "list", "List articles"
    option :feed_id, type: :numeric, desc: "Filter by feed ID"
    option :filter, type: :string, enum: %w[unread starred archived], desc: "Filter by state"
    option :limit, type: :numeric, default: 20, desc: "Number of articles"
    option :compact, type: :boolean, default: false, desc: "Use compact format"
    option :format, type: :string, default: "table", enum: %w[table json], desc: "Output format"
    def list
      config = load_config
      ensure_configured!(config)

      api_url = config["api_url"] || "http://localhost:3000/api/v1"

      endpoint = options[:compact] ? "articles/compact" : "articles"
      url = "#{api_url}/#{endpoint}?limit=#{options[:limit]}"
      url += "&feed_id=#{options[:feed_id]}" if options[:feed_id]
      url += "&filter=#{options[:filter]}" if options[:filter]

      response = HTTParty.get(
        url,
        headers: { "Authorization" => config["token"] }
      )

      if response.success?
        data = JSON.parse(response.body)
        articles = data["articles"]

        if articles.empty?
          say "No articles found"
          return
        end

        case options[:format]
        when "json"
          puts JSON.pretty_generate(articles)
        else
          articles.each do |article|
            state = article["state"] || article
            read_marker = state["read"] ? " " : "✦"
            star_marker = state["starred"] ? "★" : " "

            title = article["title"]
            feed = article["feed"] ? article["feed"]["title"] : article["feed_name"]
            published = article["published_at"]

            say "#{read_marker}#{star_marker} #{title}"
            say "   #{feed} • #{published}"
            say ""
          end

          if data["pagination"] && data["pagination"]["has_more"]
            say "More articles available (use --limit or pagination)"
          end
        end
      else
        error "Failed to fetch articles: #{response.code}"
        exit 1
      end
    end

    desc "read ARTICLE_ID", "Mark article as read"
    def read(article_id)
      config = load_config
      ensure_configured!(config)

      response = HTTParty.patch(
        "#{config["api_url"] || "http://localhost:3000/api/v1"}/articles/#{article_id}/mark_read",
        body: { read: true }.to_json,
        headers: {
          "Authorization" => config["token"],
          "Content-Type" => "application/json"
        }
      )

      if response.success?
        say "Marked as read", :green
      else
        error "Failed to update article: #{response.code}"
        exit 1
      end
    end

    desc "star ARTICLE_ID", "Toggle starred status"
    option :unstar, type: :boolean, default: false, desc: "Remove star"
    def star(article_id)
      config = load_config
      ensure_configured!(config)

      response = HTTParty.patch(
        "#{config["api_url"] || "http://localhost:3000/api/v1"}/articles/#{article_id}/mark_starred",
        body: { starred: !options[:unstar] }.to_json,
        headers: {
          "Authorization" => config["token"],
          "Content-Type" => "application/json"
        }
      )

      if response.success?
        say options[:unstar] ? "Unstarred" : "Starred", :green
      else
        error "Failed to update article: #{response.code}"
        exit 1
      end
    end

    desc "archive ARTICLE_ID", "Archive an article"
    def archive(article_id)
      config = load_config
      ensure_configured!(config)

      response = HTTParty.patch(
        "#{config["api_url"] || "http://localhost:3000/api/v1"}/articles/#{article_id}/mark_archived",
        body: { archived: true }.to_json,
        headers: {
          "Authorization" => config["token"],
          "Content-Type" => "application/json"
        }
      )

      if response.success?
        say "Archived", :green
      else
        error "Failed to archive article: #{response.code}"
        exit 1
      end
    end

    desc "show ARTICLE_ID", "Show article details"
    def show(article_id)
      config = load_config
      ensure_configured!(config)

      response = HTTParty.get(
        "#{config["api_url"] || "http://localhost:3000/api/v1"}/articles/#{article_id}",
        headers: { "Authorization" => config["token"] }
      )

      if response.success?
        data = JSON.parse(response.body)
        article = data["article"]

        say article["title"], :bold
        say "From: #{article["feed"]["title"]}"
        say "Published: #{article["published_at"]}"
        say "URL: #{article["url"]}"
        say ""

        state = article["state"]
        say "Status: #{state["read"] ? "Read" : "Unread"} | #{state["starred"] ? "★ Starred" : "☆ Not starred"}"
        say ""

        # Render content (strip HTML for terminal)
        content = article["content"].to_s.gsub(/<[^>]+>/, "")
        say content[0..2000]
        say "..." if content.length > 2000
      else
        error "Failed to fetch article: #{response.code}"
        exit 1
      end
    end

    desc "search QUERY", "Search articles"
    option :limit, type: :numeric, default: 20, desc: "Number of results"
    def search(query)
      config = load_config
      ensure_configured!(config)

      api_url = config["api_url"] || "http://localhost:3000/api/v1"
      encoded_query = CGI.escape(query)

      response = HTTParty.get(
        "#{api_url}/articles/search?q=#{encoded_query}&limit=#{options[:limit]}",
        headers: { "Authorization" => config["token"] }
      )

      if response.success?
        data = JSON.parse(response.body)
        articles = data["articles"]

        if articles.empty?
          say "No articles found for: #{query}"
          return
        end

        say "Found #{articles.length} articles for '#{query}':"
        say ""

        articles.each do |article|
          title = article["title"]
          feed = article["feed"]["title"]
          published = article["published_at"]

          say "• #{title}"
          say "  #{feed} • #{published}"
          say ""
        end
      else
        error "Search failed: #{response.code}"
        exit 1
      end
    end

    desc "mark_all_read", "Mark all articles as read"
    option :feed_id, type: :numeric, desc: "Only mark articles from this feed"
    option :category, type: :string, desc: "Only mark articles in this category"
    def mark_all_read
      config = load_config
      ensure_configured!(config)

      body = {}
      body[:feed_id] = options[:feed_id] if options[:feed_id]
      body[:category] = options[:category] if options[:category]

      response = HTTParty.post(
        "#{config["api_url"] || "http://localhost:3000/api/v1"}/articles/mark_all_read",
        body: body.to_json,
        headers: {
          "Authorization" => config["token"],
          "Content-Type" => "application/json"
        }
      )

      if response.success?
        data = JSON.parse(response.body)
        say "Marked #{data["marked_count"]} articles as read", :green
      else
        error "Failed to mark articles as read: #{response.code}"
        exit 1
      end
    end

    private

    def load_config
      if File.exist?(Silo::CLI::CONFIG_FILE)
        YAML.safe_load(File.read(Silo::CLI::CONFIG_FILE), permitted_classes: [ Time, Date ]) || {}
      else
        {}
      end
    end

    def ensure_configured!(config)
      unless config["token"]
        error "Not authenticated. Run: silo auth login"
        exit 1
      end
    end
  end
end

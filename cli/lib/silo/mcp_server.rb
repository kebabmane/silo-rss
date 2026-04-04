# frozen_string_literal: true

require "json"
require "httparty"

module Silo
  # MCP (Model Context Protocol) Server for AI agent integration
  # Communicates via stdin/stdout using JSON-RPC
  class MCPServer
    def initialize(config)
      @config = config
      @api_url = config["api_url"] || "http://localhost:3000/api/v1"
      @token = config["token"]
    end

    def start
      $stderr.puts "Silo MCP Server starting..."
      $stderr.puts "API URL: #{@api_url}"

      loop do
        line = STDIN.gets
        break if line.nil? || line.empty?

        begin
          request = JSON.parse(line)
          response = handle_request(request)
          puts response.to_json if response
        rescue JSON::ParserError => e
          $stderr.puts "Parse error: #{e.message}"
          send_error(nil, -32700, "Parse error")
        rescue StandardError => e
          $stderr.puts "Error: #{e.message}"
          send_error(nil, -32603, "Internal error: #{e.message}")
        end
      end
    end

    private

    def handle_request(request)
      id = request["id"]
      method = request["method"]
      params = request["params"] || {}

      case method
      when "initialize"
        handle_initialize(id)
      when "tools/list"
        handle_tools_list(id)
      when "tools/call"
        handle_tool_call(id, params)
      else
        send_error(id, -32601, "Method not found: #{method}")
      end
    end

    def handle_initialize(id)
      {
        jsonrpc: "2.0",
        id: id,
        result: {
          protocolVersion: "2024-11-05",
          capabilities: {
            tools: {}
          },
          serverInfo: {
            name: "silo",
            version: "1.0.0"
          }
        }
      }
    end

    def handle_tools_list(id)
      {
        jsonrpc: "2.0",
        id: id,
        result: {
          tools: [
            {
              name: "silo_list_feeds",
              description: "List all RSS feeds the user is subscribed to with unread counts",
              inputSchema: {
                type: "object",
                properties: {},
                required: []
              }
            },
            {
              name: "silo_get_unread_articles",
              description: "Get unread articles, optionally filtered by feed",
              inputSchema: {
                type: "object",
                properties: {
                  feed_id: {
                    type: "integer",
                    description: "Optional feed ID to filter by"
                  },
                  limit: {
                    type: "integer",
                    description: "Maximum number of articles to return (default: 20, max: 100)",
                    default: 20
                  }
                },
                required: []
              }
            },
            {
              name: "silo_get_starred_articles",
              description: "Get starred/saved articles",
              inputSchema: {
                type: "object",
                properties: {
                  limit: {
                    type: "integer",
                    description: "Maximum number of articles to return",
                    default: 20
                  }
                },
                required: []
              }
            },
            {
              name: "silo_search_articles",
              description: "Search articles by keyword in title or content",
              inputSchema: {
                type: "object",
                properties: {
                  query: {
                    type: "string",
                    description: "Search query"
                  },
                  limit: {
                    type: "integer",
                    description: "Maximum number of results",
                    default: 20
                  }
                },
                required: [ "query" ]
              }
            },
            {
              name: "silo_mark_read",
              description: "Mark one or more articles as read",
              inputSchema: {
                type: "object",
                properties: {
                  article_ids: {
                    type: "array",
                    items: { type: "integer" },
                    description: "Array of article IDs to mark as read"
                  }
                },
                required: [ "article_ids" ]
              }
            },
            {
              name: "silo_subscribe_feed",
              description: "Subscribe to a new RSS feed by URL",
              inputSchema: {
                type: "object",
                properties: {
                  url: {
                    type: "string",
                    description: "RSS feed URL or website URL to discover"
                  },
                  category: {
                    type: "string",
                    description: "Optional category for the feed"
                  },
                  name: {
                    type: "string",
                    description: "Optional custom display name"
                  }
                },
                required: [ "url" ]
              }
            },
            {
              name: "silo_get_article_content",
              description: "Get the full content of a specific article",
              inputSchema: {
                type: "object",
                properties: {
                  article_id: {
                    type: "integer",
                    description: "Article ID"
                  }
                },
                required: [ "article_id" ]
              }
            },
            {
              name: "silo_get_unread_count",
              description: "Get the total count of unread articles",
              inputSchema: {
                type: "object",
                properties: {},
                required: []
              }
            }
          ]
        }
      }
    end

    def handle_tool_call(id, params)
      tool_name = params["name"]
      arguments = params["arguments"] || {}

      result = case tool_name
      when "silo_list_feeds"
                 tool_list_feeds
      when "silo_get_unread_articles"
                 tool_get_unread_articles(arguments)
      when "silo_get_starred_articles"
                 tool_get_starred_articles(arguments)
      when "silo_search_articles"
                 tool_search_articles(arguments)
      when "silo_mark_read"
                 tool_mark_read(arguments)
      when "silo_subscribe_feed"
                 tool_subscribe_feed(arguments)
      when "silo_get_article_content"
                 tool_get_article_content(arguments)
      when "silo_get_unread_count"
                 tool_get_unread_count
      else
                 return send_error(id, -32602, "Unknown tool: #{tool_name}")
      end

      {
        jsonrpc: "2.0",
        id: id,
        result: result
      }
    end

    def send_error(id, code, message)
      {
        jsonrpc: "2.0",
        id: id,
        error: {
          code: code,
          message: message
        }
      }
    end

    # Tool implementations

    def tool_list_feeds
      response = api_get("#{@api_url}/feeds")

      if response.success?
        data = JSON.parse(response.body)
        feeds = data["feeds"].map do |feed|
          {
            id: feed["id"],
            name: feed["custom_name"] || feed["feed"]["title"],
            category: feed["category"],
            feed_url: feed["feed"]["feed_url"],
            site_url: feed["feed"]["site_url"],
            unread_count: feed["unread_count"] || 0
          }
        end

        {
          content: [
            {
              type: "text",
              text: "You are subscribed to #{feeds.length} feeds:\n\n" +
                    feeds.map { |f| "- #{f[:name]} (#{f[:unread_count]} unread)" }.join("\n")
            }
          ],
          data: feeds
        }
      else
        error_response("Failed to list feeds: #{response.code}")
      end
    end

    def tool_get_unread_articles(arguments)
      feed_id = arguments["feed_id"]
      limit = arguments["limit"] || 20

      url = "#{@api_url}/articles?filter=unread&limit=#{limit}"
      url += "&feed_id=#{feed_id}" if feed_id

      response = api_get(url)

      if response.success?
        data = JSON.parse(response.body)
        articles = data["articles"].map do |article|
          {
            id: article["id"],
            title: article["title"],
            feed: article["feed"]["title"],
            published_at: article["published_at"],
            url: article["url"]
          }
        end

        if articles.empty?
          {
            content: [ { type: "text", text: "No unread articles." } ],
            data: []
          }
        else
          {
            content: [
              {
                type: "text",
                text: "Found #{articles.length} unread articles:\n\n" +
                      articles.map { |a| "#{a[:id]}. #{a[:title]} (#{a[:feed]})" }.join("\n")
              }
            ],
            data: articles
          }
        end
      else
        error_response("Failed to get articles: #{response.code}")
      end
    end

    def tool_get_starred_articles(arguments)
      limit = arguments["limit"] || 20

      url = "#{@api_url}/articles?filter=starred&limit=#{limit}"
      response = api_get(url)

      if response.success?
        data = JSON.parse(response.body)
        articles = data["articles"].map do |article|
          {
            id: article["id"],
            title: article["title"],
            feed: article["feed"]["title"],
            published_at: article["published_at"]
          }
        end

        if articles.empty?
          {
            content: [ { type: "text", text: "No starred articles." } ],
            data: []
          }
        else
          {
            content: [
              {
                type: "text",
                text: "#{articles.length} starred articles:\n\n" +
                      articles.map { |a| "#{a[:id]}. #{a[:title]}" }.join("\n")
              }
            ],
            data: articles
          }
        end
      else
        error_response("Failed to get starred articles: #{response.code}")
      end
    end

    def tool_search_articles(arguments)
      query = arguments["query"]
      limit = arguments["limit"] || 20

      url = "#{@api_url}/articles/search?q=#{CGI.escape(query)}&limit=#{limit}"
      response = api_get(url)

      if response.success?
        data = JSON.parse(response.body)
        articles = data["articles"].map do |article|
          {
            id: article["id"],
            title: article["title"],
            feed: article["feed"]["title"],
            published_at: article["published_at"],
            snippet: article["content"].to_s[0..200]
          }
        end

        if articles.empty?
          {
            content: [ { type: "text", text: "No articles found for '#{query}'." } ],
            data: []
          }
        else
          {
            content: [
              {
                type: "text",
                text: "Found #{articles.length} articles matching '#{query}':\n\n" +
                      articles.map { |a| "#{a[:id]}. #{a[:title]} (#{a[:feed]})" }.join("\n")
              }
            ],
            data: articles
          }
        end
      else
        error_response("Search failed: #{response.code}")
      end
    end

    def tool_mark_read(arguments)
      article_ids = arguments["article_ids"]

      if article_ids.length == 1
        # Single article - use individual endpoint
        response = api_patch(
          "#{@api_url}/articles/#{article_ids.first}/mark_read",
          { read: true }
        )

        if response.success?
          {
            content: [ { type: "text", text: "Marked article #{article_ids.first} as read." } ],
            success: true
          }
        else
          error_response("Failed to mark as read: #{response.code}")
        end
      else
        # Multiple articles - use batch endpoint
        response = api_post(
          "#{@api_url}/articles/batch_update",
          {
            article_ids: article_ids,
            bulk_action: "mark_read",
            value: true
          }
        )

        if response.success?
          data = JSON.parse(response.body)
          {
            content: [ { type: "text", text: "Marked #{data["updated_count"]} articles as read." } ],
            success: true
          }
        else
          error_response("Failed to mark as read: #{response.code}")
        end
      end
    end

    def tool_subscribe_feed(arguments)
      url = arguments["url"]
      category = arguments["category"]
      name = arguments["name"]

      # First discover
      discover_response = api_post(
        "#{@api_url}/feeds/discover",
        { url: url }
      )

      unless discover_response.success?
        return error_response("Failed to discover feed: #{discover_response.code}")
      end

      feed_data = JSON.parse(discover_response.body)
      feed_id = feed_data["feed_id"] || feed_data["feed"]&.[]("id")

      unless feed_id
        return error_response("Could not extract feed ID from discovery response")
      end

      # Subscribe
      subscribe_response = api_post(
        "#{@api_url}/feeds",
        {
          feed_id: feed_id,
          category: category,
          custom_name: name
        }
      )

      if subscribe_response.success? || subscribe_response.code == 201
        {
          content: [ { type: "text", text: "Successfully subscribed to #{url}" } ],
          success: true
        }
      else
        error_response("Failed to subscribe: #{subscribe_response.code}")
      end
    end

    def tool_get_article_content(arguments)
      article_id = arguments["article_id"]

      response = api_get("#{@api_url}/articles/#{article_id}")

      if response.success?
        data = JSON.parse(response.body)
        article = data["article"]

        # Strip HTML for cleaner display
        content = article["content"].to_s.gsub(/<[^>]+>/, "")

        {
          content: [
            {
              type: "text",
              text: "#{article["title"]}\n" +
                    "From: #{article["feed"]["title"]}\n" +
                    "Published: #{article["published_at"]}\n" +
                    "URL: #{article["url"]}\n\n" +
                    content[0..5000]
            }
          ],
          data: article
        }
      else
        error_response("Failed to get article: #{response.code}")
      end
    end

    def tool_get_unread_count
      response = api_get("#{@api_url}/articles/unread_count")

      if response.success?
        data = JSON.parse(response.body)
        count = data["unread_count"]

        {
          content: [ { type: "text", text: "You have #{count} unread articles." } ],
          count: count
        }
      else
        error_response("Failed to get unread count: #{response.code}")
      end
    end

    # HTTP helpers

    def api_get(url)
      HTTParty.get(url, headers: { "Authorization" => @token })
    end

    def api_post(url, body)
      HTTParty.post(
        url,
        body: body.to_json,
        headers: {
          "Authorization" => @token,
          "Content-Type" => "application/json"
        }
      )
    end

    def api_patch(url, body)
      HTTParty.patch(
        url,
        body: body.to_json,
        headers: {
          "Authorization" => @token,
          "Content-Type" => "application/json"
        }
      )
    end

    def error_response(message)
      {
        content: [ { type: "text", text: "Error: #{message}" } ],
        isError: true
      }
    end
  end
end

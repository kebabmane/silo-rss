module Digest
  class ArticleClusteringService
    def initialize(articles, litellm_client, user)
      @articles = articles
      @litellm_client = litellm_client
      @user = user
    end

    def execute
      return [] if @articles.empty?

      prompt = build_prompt
      response = @litellm_client.generate_summary(prompt, max_tokens: 1000, temperature: 0.3)

      parse_clusters(response)
    rescue JSON::ParserError => e
      Rails.logger.error("ArticleClusteringService: Failed to parse clusters: #{e.message}")
      fallback_clustering
    end

    def prompt_preview
      build_prompt
    end

    private

    def build_prompt
      articles_list = @articles.map.with_index do |article, idx|
        excerpt = truncate(article.display_content || article.title, 200)
        "#{idx + 1}. [#{article.feed.title}] #{article.title}\n   #{excerpt}"
      end.join("\n\n")

      <<~PROMPT
        You are a tech news analyst. Analyze these #{@articles.count} articles and group them into 4-7 thematic clusters.

        Consider themes like:
        - AI & Machine Learning
        - Big Tech (Apple, Google, Microsoft, Meta, Amazon)
        - Startups & Funding
        - Cybersecurity & Privacy
        - Developer Tools & Programming
        - Hardware & Devices
        - Policy & Regulation
        - Business & Strategy
        - Open Source
        - Cloud & Infrastructure

        Articles:
        #{articles_list}

        Respond with ONLY valid JSON (no markdown, no explanation), in this exact format:
        {
          "clusters": [
            {
              "theme": "Theme Name",
              "description": "Brief description of what this theme covers today",
              "article_indices": [1, 4, 7],
              "importance": "high"
            }
          ]
        }

        Rules:
        - Each article should appear in exactly one cluster
        - Use article numbers (1-indexed) from the list above
        - importance should be "high", "medium", or "low"
        - Order clusters by importance (most important first)
        - Combine similar topics if they have few articles
        - Skip creating a cluster for a single article unless it's very significant
      PROMPT
    end

    def parse_clusters(response)
      # Try to extract JSON from the response
      json_match = response.match(/\{[\s\S]*\}/)
      return fallback_clustering unless json_match

      data = JSON.parse(json_match[0])
      clusters = data["clusters"] || []

      # Validate and enrich clusters
      clusters.map do |cluster|
        indices = cluster["article_indices"] || []
        {
          theme: cluster["theme"],
          description: cluster["description"],
          importance: cluster["importance"] || "medium",
          article_indices: indices.map { |i| i.to_i - 1 }, # Convert to 0-indexed
          articles: indices.map { |i| @articles[i.to_i - 1] }.compact
        }
      end.select { |c| c[:articles].any? }
    end

    def fallback_clustering
      # Simple fallback: group all articles into one cluster
      [{
        theme: "Tech News Roundup",
        description: "Today's technology news and updates",
        importance: "high",
        article_indices: (0...@articles.count).to_a,
        articles: @articles.to_a
      }]
    end

    def truncate(text, length)
      return "" if text.blank?
      text.length > length ? "#{text[0...length]}..." : text
    end
  end
end

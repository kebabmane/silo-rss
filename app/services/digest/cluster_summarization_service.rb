module Digest
  class ClusterSummarizationService
    def initialize(articles, clusters, litellm_client, user)
      @articles = articles
      @clusters = clusters
      @litellm_client = litellm_client
      @user = user
    end

    def execute
      @clusters.map do |cluster|
        summarize_cluster(cluster)
      end
    end

    private

    def summarize_cluster(cluster)
      articles = cluster[:articles]
      return empty_summary(cluster) if articles.blank?

      prompt = build_prompt(cluster, articles)
      content = @litellm_client.generate_summary(prompt, max_tokens: 1200, temperature: 0.7)

      {
        theme: cluster[:theme],
        description: cluster[:description],
        importance: cluster[:importance],
        content: content,
        article_count: articles.count,
        article_ids: articles.map(&:id)
      }
    end

    def build_prompt(cluster, articles)
      articles_text = articles.map.with_index do |article, idx|
        content = article.display_content || article.title
        published = format_date(article.published_at)

        <<~ARTICLE
          --- Article #{idx + 1} ---
          Title: #{article.title}
          Source: #{article.feed.title}
          Published: #{published}
          URL: #{article.url}

          #{truncate(content, 2500)}
        ARTICLE
      end.join("\n")

      <<~PROMPT
        You are a senior tech journalist writing for an informed, professional audience.

        Theme: #{cluster[:theme]}
        Theme Description: #{cluster[:description]}

        Write a comprehensive 400-600 word narrative summary that synthesizes these #{articles.count} articles.

        #{articles_text}

        REQUIREMENTS:
        1. **Synthesize, don't list** - Weave the stories together into a cohesive narrative
        2. **Lead with the most significant development** - What's the headline story?
        3. **Include specific details** - Company names, numbers, quotes when relevant
        4. **Explain significance** - Why should readers care? What does this mean?
        5. **Write engagingly** - This should read like a newsletter, not a dry report
        6. **Use markdown formatting** - Headers, bold for emphasis, bullet points where helpful

        FORMAT:
        - Start with a compelling lead paragraph summarizing the key development
        - Use **bold** for company names and key figures on first mention
        - Include relevant statistics or quotes
        - End with forward-looking context (what to watch for)
        - Include [source links](url) for major claims

        Do NOT:
        - List articles one by one
        - Use phrases like "Article 1 discusses..."
        - Include redundant information
        - Pad with generic statements
      PROMPT
    end

    def empty_summary(cluster)
      {
        theme: cluster[:theme],
        description: cluster[:description],
        importance: cluster[:importance],
        content: "_No articles in this category today._",
        article_count: 0,
        article_ids: []
      }
    end

    def format_date(datetime)
      return "Unknown" if datetime.blank?
      datetime.in_time_zone(@user.time_zone_or_default).strftime("%B %d, %Y")
    end

    def truncate(text, length)
      return "" if text.blank?
      text.length > length ? "#{text[0...length]}..." : text
    end
  end
end

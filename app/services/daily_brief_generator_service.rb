class DailyBriefGeneratorService
  class Error < StandardError; end

  def initialize(schedule)
    @schedule = schedule
    @user = schedule.user
    @litellm_client = LitellmClientService.new
  end

  # Generate a daily brief for the schedule
  def generate
    # Get unread articles from the past 24 hours
    articles = fetch_unread_articles

    # Return early if no articles
    if articles.empty?
      return create_empty_brief
    end

    # Prepare content for summarization
    content = prepare_content_for_summary(articles)

    # Generate summary using LiteLLM
    summary = generate_summary(content)

    # Create the daily brief record
    brief = create_brief(summary, articles.count)

    brief
  rescue LitellmClientService::Error => e
    Rails.logger.error("Failed to generate daily brief for schedule #{@schedule.id}: #{e.message}")
    raise Error, "Failed to generate daily brief: #{e.message}"
  end

  private

  def fetch_unread_articles
    # Get feeds to include
    feeds = @schedule.feeds_to_include
    feed_ids = feeds.map(&:id) # Use map instead of pluck to avoid extra query if already loaded

    # Get articles from the past 24 hours that are unread
    # Use left_joins for better performance and safety
    Article
      .joins(:feed)
      .left_joins(:article_states)
      .where(feed_id: feed_ids)
      .where("articles.published_at >= ?", 24.hours.ago)
      .where("article_states.id IS NULL OR (article_states.user_id = ? AND article_states.read = ?)", @user.id, false)
      .order(published_at: :desc)
      .limit(100) # Limit to prevent overwhelming the LLM
  end

  def prepare_content_for_summary(articles)
    summary_instructions = case @schedule.summary_length
    when "short"
      "Create a brief summary (2-3 sentences per article) of the following articles:"
    when "medium"
      "Create a moderate summary (1 paragraph per article) of the following articles:"
    when "detailed"
      "Create a detailed summary (2-3 paragraphs per article) of the following articles:"
    else
      "Summarize the following articles:"
    end

    articles_text = articles.map.with_index do |article, index|
      content = article.display_content || article.title
      feed_name = article.feed.title

      published_at_text = if article.published_at.present?
                             article.published_at.in_time_zone(user_time_zone).strftime("%B %d, %Y %I:%M %p")
                           else
                             "Unknown"
                           end

      <<~ARTICLE
        Article #{index + 1}: #{article.title}
        Source: #{feed_name}
        Published: #{published_at_text}
        URL: #{article.url}

        #{truncate_content(content, 2000)}

        ---
      ARTICLE
    end.join("\n")

    <<~PROMPT
      #{summary_instructions}

      You have #{articles.count} articles to summarize from the past 24 hours.

      **IMPORTANT FORMATTING INSTRUCTIONS:**
      - Use proper markdown formatting throughout
      - Start with an "## Overview" section (2-3 sentences) highlighting the main themes or topics
      - Then add an "## Article Summaries" section
      - For each article, use "### Article Title" (h3 heading) for the article title
      - Below each article title, add metadata in italics: *Source: [feed_name] | Published: [date]*
      - After the metadata, add a "Read more" link using the article URL provided
      - Then provide the summary content based on the requested detail level
      - Use **bold** for emphasis on key points
      - Use bullet points when listing multiple related items
      - Separate each article with extra spacing for readability
      - Make article titles standalone on their own line for easy scanning

      Example format:
      ## Overview
      [Your overview text here]

      ## Article Summaries

      ### Article Title Here
      *Source: TechCrunch | Published: October 04, 2025*

      [Read more](article-url-here)

      [Summary content here with **bold** for emphasis and bullet points as needed]

      ### Another Article Title
      *Source: Hacker News | Published: October 04, 2025*

      [Read more](article-url-here)

      [Summary content here]

      #{articles_text}
    PROMPT
  end

  def generate_summary(content)
    max_tokens = case @schedule.summary_length
    when "short"
      1500
    when "medium"
      3000
    when "detailed"
      6000
    else
      3000
    end

    @litellm_client.generate_summary(content, max_tokens: max_tokens)
  end

  def create_brief(summary, article_count)
    DailyBrief.create!(
      user: @user,
      daily_brief_schedule: @schedule,
      content: summary,
      article_count: article_count,
      generated_at: Time.current
    )
  end

  def create_empty_brief
    DailyBrief.create!(
      user: @user,
      daily_brief_schedule: @schedule,
      content: "No new articles to summarize from the past 24 hours.",
      article_count: 0,
      generated_at: Time.current
    )
  end

  def truncate_content(text, max_length)
    return text if text.length <= max_length

    text[0...max_length] + "..."
  end

  def user_time_zone
    @user.time_zone_or_default
  end
end

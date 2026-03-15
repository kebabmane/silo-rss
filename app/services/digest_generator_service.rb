class DigestGeneratorService
  include UnreadArticlesQuery

  class Error < StandardError; end

  PIPELINE_STEPS = %i[cluster summarize analyze compose polish].freeze

  def initialize(schedule)
    @schedule = schedule
    @user = schedule.user
    @litellm_client = LitellmClientService.new
    @pipeline_results = {}
    @start_time = nil
  end

  # Generate a full narrative digest
  def generate
    @start_time = Time.current
    articles = fetch_unread_articles

    if articles.empty?
      return create_empty_digest
    end

    # Execute the multi-step pipeline
    execute_pipeline(articles)

    # Build and save the final digest
    create_digest(articles)
  rescue LitellmClientService::Error => e
    Rails.logger.error("DigestGeneratorService: LLM error for schedule #{@schedule.id}: #{e.message}")
    raise Error, "Failed to generate digest: #{e.message}"
  rescue => e
    Rails.logger.error("DigestGeneratorService: Unexpected error for schedule #{@schedule.id}: #{e.message}")
    Rails.logger.error(e.backtrace.first(10).join("\n"))
    raise Error, "Failed to generate digest: #{e.message}"
  end

  # Preview the digest generation (for admin tools)
  def prompt_preview
    articles = fetch_unread_articles
    clustering_service = Digest::ArticleClusteringService.new(articles, @litellm_client, @user)

    {
      articles_count: articles.count,
      clustering_prompt: clustering_service.prompt_preview,
      articles: articles.first(10)
    }
  end

  private

  def execute_pipeline(articles)
    # Step 1: Cluster articles by theme
    log_step(:cluster, "Starting article clustering")
    @pipeline_results[:clusters] = Digest::ArticleClusteringService
      .new(articles, @litellm_client, @user)
      .execute
    log_step(:cluster, "Clustered into #{@pipeline_results[:clusters].count} themes")

    # Step 2: Summarize each cluster
    log_step(:summarize, "Starting cluster summarization")
    @pipeline_results[:summaries] = Digest::ClusterSummarizationService
      .new(articles, @pipeline_results[:clusters], @litellm_client, @user)
      .execute
    log_step(:summarize, "Generated #{@pipeline_results[:summaries].count} theme summaries")

    # Step 3: Analyze trends across clusters
    log_step(:analyze, "Starting trend analysis")
    @pipeline_results[:trends] = Digest::TrendAnalysisService
      .new(@pipeline_results[:summaries], @litellm_client)
      .execute
    log_step(:analyze, "Identified trends and connections")

    # Step 4: Compose the narrative structure
    log_step(:compose, "Starting narrative composition")
    @pipeline_results[:narrative] = Digest::NarrativeCompositionService
      .new(@pipeline_results[:summaries], @pipeline_results[:trends], @litellm_client)
      .execute
    log_step(:compose, "Composed narrative structure")

    # Step 5: Polish and finalize
    log_step(:polish, "Starting editorial polish")
    polish_service = Digest::EditorialPolishService.new(@pipeline_results[:narrative], @litellm_client)
    polish_service.summaries = @pipeline_results[:summaries]
    polish_service.trends = @pipeline_results[:trends]
    @pipeline_results[:final] = polish_service.execute
    log_step(:polish, "Finalized digest")
  end

  def create_digest(articles)
    content = @pipeline_results[:final][:content]
    sections = @pipeline_results[:final][:sections] || []
    themes = @pipeline_results[:clusters].map { |c| c[:theme] }

    DailyBrief.create!(
      user: @user,
      daily_brief_schedule: @schedule,
      content: content,
      article_count: articles.count,
      generated_at: Time.current,
      digest_type: "digest",
      sections: sections,
      themes: themes,
      reading_time_minutes: calculate_reading_time(content),
      generation_metadata: build_metadata,
      article_ids: articles.map(&:id)
    ).tap { |brief| notify_digest_created(brief) }
  end

  def create_empty_digest
    DailyBrief.create!(
      user: @user,
      daily_brief_schedule: @schedule,
      content: "# No New Articles Today\n\nThere were no new articles from your subscribed feeds in the past 24 hours. Check back tomorrow for your Daily Tech Digest.",
      article_count: 0,
      generated_at: Time.current,
      digest_type: "digest",
      sections: [],
      themes: [],
      reading_time_minutes: 1,
      generation_metadata: { empty: true },
      article_ids: []
    ).tap { |brief| notify_digest_created(brief) }
  end

  def calculate_reading_time(content)
    return 0 if content.blank?
    words = content.split.size
    (words / 200.0).ceil
  end

  def build_metadata
    {
      pipeline_version: "1.0",
      total_duration_seconds: Time.current - @start_time,
      steps_completed: @pipeline_results.keys,
      cluster_count: @pipeline_results[:clusters]&.count || 0,
      generated_at: Time.current.iso8601
    }
  end

  def notify_digest_created(brief)
    PushNotificationService.daily_brief_generated(@user, brief)
  rescue => e
    Rails.logger.warn("Digest push notification failed: #{e.message}")
  end

  def log_step(step, message)
    Rails.logger.info("DigestGeneratorService [#{@schedule.id}] #{step}: #{message}")
  end
end

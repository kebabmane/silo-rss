require "test_helper"

class DigestGeneratorServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:alice)
    @schedule = daily_brief_schedules(:one)
    # Mock the litellm client to avoid configuration errors
    LitellmClientService.stubs(:new).returns(mock("LitellmClientService"))
    @service = DigestGeneratorService.new(@schedule)
  end

  # Empty articles scenario
  test "generate creates empty digest when no unread articles" do
    # Mock no articles
    @service.stubs(:fetch_unread_articles).returns([])

    assert_difference "DailyBrief.count", 1 do
      result = @service.generate

      assert_equal @user, result.user
      assert_equal @schedule, result.daily_brief_schedule
      assert_equal 0, result.article_count
      assert_equal "digest", result.digest_type
      assert result.content.include?("No New Articles Today")
      assert_empty result.article_ids
      assert_empty result.sections
      assert_empty result.themes
    end
  end

  # Pipeline execution
  test "generate executes full pipeline with articles" do
    articles = [ articles(:tc_article_1), articles(:tc_article_2) ]
    @service.stubs(:fetch_unread_articles).returns(articles)

    # Mock all pipeline services
    clusters = [ { theme: "AI", articles: [ articles.first ] } ]
    summaries = [ { theme: "AI", content: "Summary" } ]
    trends = { content: "Trend analysis" }
    narrative = { opening: "Opening", transitions: {}, closing: "Closing" }
    final = { content: "Final content", sections: [ { title: "Section" } ] }

    Digest::ArticleClusteringService.any_instance.stubs(:execute).returns(clusters)
    Digest::ClusterSummarizationService.any_instance.stubs(:execute).returns(summaries)
    Digest::TrendAnalysisService.any_instance.stubs(:execute).returns(trends)
    Digest::NarrativeCompositionService.any_instance.stubs(:execute).returns(narrative)

    polish_service = mock("EditorialPolishService")
    Digest::EditorialPolishService.expects(:new)
      .with(narrative, anything)
      .returns(polish_service)
    polish_service.expects(:summaries=).with(summaries)
    polish_service.expects(:trends=).with(trends)
    polish_service.expects(:execute).returns(final)

    PushNotificationService.stubs(:daily_brief_generated)

    assert_difference "DailyBrief.count", 1 do
      result = @service.generate

      assert_equal "Final content", result.content
      assert_equal 2, result.article_count
      assert_equal articles.map(&:id), result.article_ids
      assert_equal [ "AI" ], result.themes
    end
  end

  # LLM error handling
  test "generate raises DigestGeneratorService::Error on LLM failure" do
    articles = [ articles(:tc_article_1) ]
    @service.stubs(:fetch_unread_articles).returns(articles)

    llm_error = LitellmClientService::Error.new("LLM API failed")
    Digest::ArticleClusteringService.any_instance.stubs(:execute).raises(llm_error)

    error = assert_raises DigestGeneratorService::Error do
      @service.generate
    end

    assert_includes error.message, "Failed to generate digest"
    assert_includes error.message, "LLM API failed"
  end

  # Unexpected error handling
  test "generate raises DigestGeneratorService::Error on unexpected errors" do
    articles = [ articles(:tc_article_1) ]
    @service.stubs(:fetch_unread_articles).returns(articles)

    Digest::ArticleClusteringService.any_instance.stubs(:execute).raises(StandardError.new("Unexpected"))

    error = assert_raises DigestGeneratorService::Error do
      @service.generate
    end

    assert_includes error.message, "Failed to generate digest"
  end

  # Notification handling
  test "generate sends push notification after creation" do
    articles = [ articles(:tc_article_1) ]
    @service.stubs(:fetch_unread_articles).returns(articles)

    # Mock pipeline
    Digest::ArticleClusteringService.any_instance.stubs(:execute).returns([])
    Digest::ClusterSummarizationService.any_instance.stubs(:execute).returns([])
    Digest::TrendAnalysisService.any_instance.stubs(:execute).returns({ content: "" })
    Digest::NarrativeCompositionService.any_instance.stubs(:execute).returns({})

    polish_service = mock("EditorialPolishService")
    Digest::EditorialPolishService.stubs(:new).returns(polish_service)
    polish_service.stubs(:summaries=)
    polish_service.stubs(:trends=)
    polish_service.stubs(:execute).returns({ content: "Content", sections: [] })

    PushNotificationService.expects(:daily_brief_generated)
      .with(@user, instance_of(DailyBrief))

    @service.generate
  end

  test "generate logs warning when push notification fails" do
    articles = [ articles(:tc_article_1) ]
    @service.stubs(:fetch_unread_articles).returns(articles)

    # Mock pipeline
    Digest::ArticleClusteringService.any_instance.stubs(:execute).returns([])
    Digest::ClusterSummarizationService.any_instance.stubs(:execute).returns([])
    Digest::TrendAnalysisService.any_instance.stubs(:execute).returns({ content: "" })
    Digest::NarrativeCompositionService.any_instance.stubs(:execute).returns({})

    polish_service = mock("EditorialPolishService")
    Digest::EditorialPolishService.stubs(:new).returns(polish_service)
    polish_service.stubs(:summaries=)
    polish_service.stubs(:trends=)
    polish_service.stubs(:execute).returns({ content: "Content", sections: [] })

    PushNotificationService.stubs(:daily_brief_generated).raises(StandardError.new("Push failed"))
    Rails.logger.expects(:warn).with(includes("Digest push notification failed"))

    # Should not raise - notification failure shouldn't fail digest creation
    assert_nothing_raised do
      @service.generate
    end
  end

  # Metadata building
  test "generate includes correct metadata" do
    articles = [ articles(:tc_article_1) ]
    @service.stubs(:fetch_unread_articles).returns(articles)

    # Mock pipeline
    Digest::ArticleClusteringService.any_instance.stubs(:execute).returns([ { theme: "Test" } ])
    Digest::ClusterSummarizationService.any_instance.stubs(:execute).returns([])
    Digest::TrendAnalysisService.any_instance.stubs(:execute).returns({ content: "" })
    Digest::NarrativeCompositionService.any_instance.stubs(:execute).returns({})

    polish_service = mock("EditorialPolishService")
    Digest::EditorialPolishService.stubs(:new).returns(polish_service)
    polish_service.stubs(:summaries=)
    polish_service.stubs(:trends=)
    polish_service.stubs(:execute).returns({ content: "Content", sections: [] })

    PushNotificationService.stubs(:daily_brief_generated)

    result = @service.generate

    metadata = result.generation_metadata
    assert_equal "1.0", metadata["pipeline_version"]
    assert_includes metadata["steps_completed"], :clusters
    assert metadata["total_duration_seconds"] >= 0
    assert metadata["generated_at"].present?
  end

  # Reading time calculation
  test "calculate_reading_time returns 0 for blank content" do
    result = @service.send(:calculate_reading_time, "")
    assert_equal 0, result
  end

  test "calculate_reading_time calculates correctly for content" do
    # 400 words at 200 wpm = 2 minutes
    content = "word " * 400
    result = @service.send(:calculate_reading_time, content)
    assert_equal 2, result
  end

  test "calculate_reading_time rounds up" do
    # 201 words at 200 wpm = 2 minutes (rounded up)
    content = "word " * 201
    result = @service.send(:calculate_reading_time, content)
    assert_equal 2, result
  end

  # Prompt preview
  test "prompt_preview returns article count and clustering prompt" do
    articles = [ articles(:tc_article_1), articles(:tc_article_2) ]
    @service.stubs(:fetch_unread_articles).returns(articles)

    clustering_service = mock("ArticleClusteringService")
    Digest::ArticleClusteringService.expects(:new)
      .with(articles, anything, @user)
      .returns(clustering_service)
    clustering_service.expects(:prompt_preview).returns("Clustering prompt text")

    preview = @service.prompt_preview

    assert_equal 2, preview[:articles_count]
    assert_equal "Clustering prompt text", preview[:clustering_prompt]
    assert_equal articles.first(10), preview[:articles]
  end
end

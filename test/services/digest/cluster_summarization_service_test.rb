require "test_helper"

module Digest
  class ClusterSummarizationServiceTest < ActiveSupport::TestCase
    setup do
      @articles = [ articles(:tc_article_1), articles(:tc_article_2) ]
      @clusters = [
        {
          theme: "AI & Machine Learning",
          description: "AI developments today",
          importance: "high",
          articles: [ @articles.first ]
        }
      ]
      @litellm_client = mock("LitellmClientService")
      @user = users(:alice)
      @service = ClusterSummarizationService.new(@articles, @clusters, @litellm_client, @user)
    end

    # Success scenarios
    test "execute returns summaries for each cluster" do
      summary_text = "AI is transforming the industry with new breakthroughs in machine learning."

      @litellm_client.expects(:generate_summary)
        .with(anything, max_tokens: 1200, temperature: 0.7)
        .returns(summary_text)

      result = @service.execute

      assert_equal 1, result.count
      assert_equal "AI & Machine Learning", result.first[:theme]
      assert_equal "AI developments today", result.first[:description]
      assert_equal "high", result.first[:importance]
      assert_equal summary_text, result.first[:content]
      assert_equal 1, result.first[:article_count]
      assert_equal [ @articles.first.id ], result.first[:article_ids]
    end

    test "execute processes multiple clusters" do
      clusters = [
        { theme: "AI", description: "AI news", importance: "high", articles: [ @articles.first ] },
        { theme: "Security", description: "Security news", importance: "medium", articles: [ @articles.second ] }
      ]

      service = ClusterSummarizationService.new(@articles, clusters, @litellm_client, @user)

      @litellm_client.expects(:generate_summary).twice.returns("Summary 1", "Summary 2")

      result = service.execute

      assert_equal 2, result.count
      assert_equal "Summary 1", result[0][:content]
      assert_equal "Summary 2", result[1][:content]
    end

    test "execute includes all articles from cluster" do
      cluster = {
        theme: "Tech News",
        description: "Mixed news",
        importance: "medium",
        articles: @articles
      }

      service = ClusterSummarizationService.new(@articles, [ cluster ], @litellm_client, @user)

      @litellm_client.stubs(:generate_summary).returns("Summary")

      result = service.execute

      assert_equal 2, result.first[:article_count]
      assert_equal @articles.map(&:id), result.first[:article_ids]
    end

    # Empty cluster handling
    test "execute returns empty summary for cluster with no articles" do
      cluster = {
        theme: "Empty Theme",
        description: "No articles here",
        importance: "low",
        articles: []
      }

      service = ClusterSummarizationService.new(@articles, [ cluster ], @litellm_client, @user)

      @litellm_client.expects(:generate_summary).never

      result = service.execute

      assert_equal "Empty Theme", result.first[:theme]
      assert_equal "_No articles in this category today._", result.first[:content]
      assert_equal 0, result.first[:article_count]
      assert_empty result.first[:article_ids]
    end

    # Prompt building
    test "build_prompt includes article details" do
      cluster = {
        theme: "Test Theme",
        description: "Test description",
        importance: "high",
        articles: [ @articles.first ]
      }

      service = ClusterSummarizationService.new(@articles, [ cluster ], @litellm_client, @user)

      @litellm_client.expects(:generate_summary) do |prompt, **options|
        assert_includes prompt, "Test Theme"
        assert_includes prompt, "Test description"
        assert_includes prompt, @articles.first.title
        assert_includes prompt, @articles.first.feed.title
        assert_includes prompt, "synthesize, don't list"
        assert_equal 1200, options[:max_tokens]
        assert_equal 0.7, options[:temperature]
        "Summary"
      end

      service.execute
    end

    test "build_prompt includes published date formatted in user timezone" do
      @articles.first.update!(published_at: Time.parse("2024-01-15 10:00:00 UTC"))

      cluster = {
        theme: "Test",
        description: "Test",
        importance: "high",
        articles: [ @articles.first ]
      }

      service = ClusterSummarizationService.new(@articles, [ cluster ], @litellm_client, @user)

      @litellm_client.expects(:generate_summary) do |prompt, **|
        # Should include formatted date
        assert_includes prompt, "January 15, 2024"
        "Summary"
      end

      service.execute
    end

    test "build_prompt truncates long content" do
      long_article = @articles.first
      long_article.stubs(:display_content).returns("a" * 5000)

      cluster = {
        theme: "Test",
        description: "Test",
        importance: "high",
        articles: [ long_article ]
      }

      service = ClusterSummarizationService.new(@articles, [ cluster ], @litellm_client, @user)

      @litellm_client.expects(:generate_summary) do |prompt, **|
        # Should be truncated
        refute_includes prompt, "a" * 3000
        assert_includes prompt, "..."
        "Summary"
      end

      service.execute
    end

    # Date formatting
    test "format_date returns Unknown for blank datetime" do
      result = @service.send(:format_date, nil)
      assert_equal "Unknown", result
    end

    test "format_date formats in user timezone" do
      datetime = Time.parse("2024-03-15 14:30:00 UTC")
      result = @service.send(:format_date, datetime)

      # Should be formatted in user's timezone (from fixtures)
      assert_includes result, "March 15, 2024"
    end

    # Truncation
    test "truncate returns empty string for blank text" do
      result = @service.send(:truncate, "", 100)
      assert_equal "", result
    end

    test "truncate returns original text if under limit" do
      result = @service.send(:truncate, "short", 100)
      assert_equal "short", result
    end

    test "truncate adds ellipsis when truncating" do
      text = "a" * 100
      result = @service.send(:truncate, text, 50)
      assert_equal 53, result.length # 50 chars + "..."
      assert_includes result, "..."
    end
  end
end

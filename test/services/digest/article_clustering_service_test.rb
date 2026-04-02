require "test_helper"

module Digest
  class ArticleClusteringServiceTest < ActiveSupport::TestCase
    setup do
      @articles = [ articles(:tc_article_1), articles(:tc_article_2), articles(:hn_article_1) ]
      @litellm_client = mock("LitellmClientService")
      @user = users(:alice)
      @service = ArticleClusteringService.new(@articles, @litellm_client, @user)
    end

    # Success scenarios
    test "execute returns clusters when LLM responds with valid JSON" do
      json_response = {
        clusters: [
          {
            theme: "AI & Machine Learning",
            description: "AI developments",
            article_indices: [ 1, 2 ],
            importance: "high"
          }
        ]
      }.to_json

      @litellm_client.expects(:generate_summary)
        .with(anything, max_tokens: 1000, temperature: 0.3)
        .returns(json_response)

      result = @service.execute

      assert_equal 1, result.count
      assert_equal "AI & Machine Learning", result.first[:theme]
      assert_equal "AI developments", result.first[:description]
      assert_equal "high", result.first[:importance]
      # Converted to 0-indexed
      assert_equal [ 0, 1 ], result.first[:article_indices]
      assert_equal [ @articles[0], @articles[1] ], result.first[:articles]
    end

    test "execute handles multiple clusters" do
      json_response = {
        clusters: [
          {
            theme: "AI",
            description: "AI news",
            article_indices: [ 1 ],
            importance: "high"
          },
          {
            theme: "Security",
            description: "Security news",
            article_indices: [ 2, 3 ],
            importance: "medium"
          }
        ]
      }.to_json

      @litellm_client.stubs(:generate_summary).returns(json_response)

      result = @service.execute

      assert_equal 2, result.count
      assert_equal [ 0 ], result[0][:article_indices]
      assert_equal [ 1, 2 ], result[1][:article_indices]
    end

    test "execute filters out clusters with no valid articles" do
      json_response = {
        clusters: [
          {
            theme: "Valid Cluster",
            description: "Has articles",
            article_indices: [ 1 ],
            importance: "high"
          },
          {
            theme: "Invalid Cluster",
            description: "No valid articles",
            article_indices: [ 99 ], # Out of range
            importance: "low"
          }
        ]
      }.to_json

      @litellm_client.stubs(:generate_summary).returns(json_response)

      result = @service.execute

      assert_equal 1, result.count
      assert_equal "Valid Cluster", result.first[:theme]
    end

    test "execute handles missing importance field" do
      json_response = {
        clusters: [
          {
            theme: "AI",
            description: "AI news",
            article_indices: [ 1 ]
            # importance is missing
          }
        ]
      }.to_json

      @litellm_client.stubs(:generate_summary).returns(json_response)

      result = @service.execute

      assert_equal "medium", result.first[:importance] # Default value
    end

    # Empty articles
    test "execute returns empty array when no articles" do
      service = ArticleClusteringService.new([], @litellm_client, @user)

      @litellm_client.expects(:generate_summary).never

      result = service.execute
      assert_empty result
    end

    # JSON parsing errors
    test "execute falls back to single cluster when JSON parsing fails" do
      @litellm_client.stubs(:generate_summary).returns("Invalid JSON")

      Rails.logger.expects(:error).with(includes("Failed to parse clusters"))

      result = @service.execute

      assert_equal 1, result.count
      assert_equal "Tech News Roundup", result.first[:theme]
      assert_equal @articles, result.first[:articles]
    end

    test "execute falls back when response has no JSON object" do
      @litellm_client.stubs(:generate_summary).returns("Just some text without JSON")

      result = @service.execute

      assert_equal 1, result.count
      assert_equal "Tech News Roundup", result.first[:theme]
    end

    # Prompt preview
    test "prompt_preview returns the clustering prompt" do
      prompt = @service.prompt_preview

      assert_includes prompt, "tech news analyst"
      assert_includes prompt, @articles.count.to_s
      assert_includes prompt, @articles.first.title
      assert_includes prompt, "AI & Machine Learning"
      assert_includes prompt, "Big Tech"
      assert_includes prompt, "valid JSON"
    end

    test "prompt_preview includes article excerpts" do
      prompt = @service.prompt_preview

      @articles.each do |article|
        assert_includes prompt, article.title
        assert_includes prompt, article.feed.title
      end
    end

    # Prompt building
    test "build_prompt truncates long content" do
      long_article = articles(:tc_article_1)
      long_article.stubs(:display_content).returns("a" * 1000)

      service = ArticleClusteringService.new([ long_article ], @litellm_client, @user)
      prompt = service.prompt_preview

      # Should be truncated with ...
      assert_includes prompt, "..."
    end

    # Edge cases
    test "execute handles JSON with markdown code blocks" do
      json_response = "```json\n{\"clusters\": []}\n```"
      @litellm_client.stubs(:generate_summary).returns(json_response)

      result = @service.execute

      # Should still parse the JSON inside
      assert_empty result
    end

    test "execute handles empty clusters array" do
      json_response = { clusters: [] }.to_json
      @litellm_client.stubs(:generate_summary).returns(json_response)

      result = @service.execute

      assert_empty result
    end

    test "execute filters duplicate article indices" do
      json_response = {
        clusters: [
          {
            theme: "Cluster 1",
            description: "Description",
            article_indices: [ 1, 1, 2 ], # Duplicate 1
            importance: "high"
          }
        ]
      }.to_json

      @litellm_client.stubs(:generate_summary).returns(json_response)

      result = @service.execute

      # Should deduplicate indices but still get both unique articles
      assert_equal [ 0, 1 ], result.first[:article_indices]
      assert_equal 2, result.first[:articles].count
    end
  end
end

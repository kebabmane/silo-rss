require "test_helper"

module Digest
  class TrendAnalysisServiceTest < ActiveSupport::TestCase
    setup do
      @summaries = [
        { theme: "AI", content: "AI developments..." },
        { theme: "Security", content: "Security news..." }
      ]
      @litellm_client = mock("LitellmClientService")
      @service = TrendAnalysisService.new(@summaries, @litellm_client)
    end

    # Success scenarios
    test "execute returns trend analysis when multiple summaries exist" do
      trend_content = "The convergence of AI and security represents a major industry shift."

      @litellm_client.expects(:generate_summary)
        .with(anything, max_tokens: 800, temperature: 0.7)
        .returns(trend_content)

      result = @service.execute

      assert_equal trend_content, result[:content]
      assert_equal [ "AI", "Security" ], result[:themes_analyzed]
    end

    test "execute includes all themes in metadata" do
      summaries = [
        { theme: "Cloud", content: "Cloud news..." },
        { theme: "Mobile", content: "Mobile updates..." },
        { theme: "Web", content: "Web developments..." }
      ]

      service = TrendAnalysisService.new(summaries, @litellm_client)

      @litellm_client.stubs(:generate_summary).returns("Analysis")

      result = service.execute

      assert_equal [ "Cloud", "Mobile", "Web" ], result[:themes_analyzed]
    end

    # Guard clauses
    test "execute returns default trends when no summaries" do
      service = TrendAnalysisService.new([], @litellm_client)

      @litellm_client.expects(:generate_summary).never

      result = service.execute

      assert_equal "_Trend analysis requires multiple themes to identify patterns._", result[:content]
      assert_empty result[:themes_analyzed]
    end

    test "execute returns default trends when only one summary" do
      single_summary = [ { theme: "AI", content: "Only AI news..." } ]
      service = TrendAnalysisService.new(single_summary, @litellm_client)

      @litellm_client.expects(:generate_summary).never

      result = service.execute

      assert_equal "_Trend analysis requires multiple themes to identify patterns._", result[:content]
      assert_equal [ "AI" ], result[:themes_analyzed]
    end

    # Prompt building
    test "build_prompt includes all summaries" do
      @litellm_client.expects(:generate_summary) do |prompt, **options|
        assert_includes prompt, "AI"
        assert_includes prompt, "Security"
        assert_includes prompt, "AI developments..."
        assert_includes prompt, "Security news..."
        assert_includes prompt, "tech industry analyst"
        assert_includes prompt, "cross-cutting trends"
        assert_equal 800, options[:max_tokens]
        assert_equal 0.7, options[:temperature]
        "Analysis"
      end

      @service.execute
    end

    test "build_prompt formats summaries with headers" do
      @litellm_client.expects(:generate_summary) do |prompt, **|
        # Should have markdown headers for each summary
        assert_includes prompt, "## AI"
        assert_includes prompt, "## Security"
        # Should have separator
        assert_includes prompt, "---"
        "Analysis"
      end

      @service.execute
    end

    # Edge cases
    test "execute handles empty content from LLM" do
      @litellm_client.stubs(:generate_summary).returns("")

      result = @service.execute

      assert_equal "", result[:content]
      assert_equal [ "AI", "Security" ], result[:themes_analyzed]
    end

    test "execute handles summaries with special characters in theme names" do
      summaries = [
        { theme: "AI & ML (2024)", content: "Content..." },
        { theme: "Security & Privacy", content: "Content..." }
      ]

      service = TrendAnalysisService.new(summaries, @litellm_client)

      @litellm_client.stubs(:generate_summary).returns("Analysis")

      result = service.execute

      assert_equal [ "AI & ML (2024)", "Security & Privacy" ], result[:themes_analyzed]
    end
  end
end

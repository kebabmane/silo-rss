require "test_helper"

module Digest
  class EditorialPolishServiceTest < ActiveSupport::TestCase
    setup do
      @narrative = {
        opening: "Today's tech news is exciting.",
        transitions: {
          "AI" => "Meanwhile in AI...",
          "Security" => "On the security front..."
        },
        closing: "Stay tuned for more."
      }
      @litellm_client = mock("LitellmClientService")
      @service = EditorialPolishService.new(@narrative, @litellm_client)
    end

    # Full assembly with summaries and trends
    test "execute assembles full document with summaries and trends" do
      summaries = [
        { theme: "AI", content: "AI news content..." },
        { theme: "Security", content: "Security news content..." }
      ]
      trends = { content: "Trend analysis..." }

      service = EditorialPolishService.with_full_context(summaries, trends, @narrative, @litellm_client)

      result = service.execute

      assert result[:content].present?
      assert_includes result[:content], "Daily Tech Digest"
      assert_includes result[:content], "Today's tech news is exciting" # Opening
      assert_includes result[:content], "AI news content" # Summary 1
      assert_includes result[:content], "Security news content" # Summary 2
      assert_includes result[:content], "On the security front..." # Transition (idx > 0)
      assert_includes result[:content], "Trend analysis" # Trends
      assert_includes result[:content], "Stay tuned for more" # Closing
      assert result[:sections].is_a?(Array)
    end

    test "execute formats document with proper markdown structure" do
      summaries = [ { theme: "AI", content: "AI content" } ]

      service = EditorialPolishService.with_full_context(summaries, nil, @narrative, @litellm_client)

      result = service.execute

      # Should have markdown headers
      assert_includes result[:content], "# Daily Tech Digest"
      assert_includes result[:content], "## The Big Picture"
      assert_includes result[:content], "## AI"
      assert_includes result[:content], "## Looking Ahead"
      # Should have separators
      assert_includes result[:content], "---"
    end

    test "execute includes transition sentences between themes" do
      summaries = [
        { theme: "AI", content: "AI content" },
        { theme: "Security", content: "Security content" }
      ]

      service = EditorialPolishService.with_full_context(summaries, nil, @narrative, @litellm_client)

      result = service.execute

      # First theme shouldn't have transition (idx 0)
      # Second theme should have transition
      assert_includes result[:content], "_On the security front..._"
    end

    test "execute includes trends section when trends provided" do
      summaries = [ { theme: "AI", content: "AI content" } ]
      trends = { content: "Connecting the dots analysis..." }

      service = EditorialPolishService.with_full_context(summaries, trends, @narrative, @litellm_client)

      result = service.execute

      assert_includes result[:content], "## Connecting the Dots"
      assert_includes result[:content], "Connecting the dots analysis"
    end

    test "execute skips trends section when no trends content" do
      summaries = [ { theme: "AI", content: "AI content" } ]
      trends = { content: "" }

      service = EditorialPolishService.with_full_context(summaries, trends, @narrative, @litellm_client)

      result = service.execute

      refute_includes result[:content], "Connecting the Dots"
    end

    # Simple polish without summaries
    test "execute returns raw content when no summaries provided" do
      simple_narrative = { raw_content: "Simple content" }
      service = EditorialPolishService.new(simple_narrative, @litellm_client)

      result = service.execute

      assert_equal "Simple content", result[:content]
    end

    test "execute returns empty string when no raw_content" do
      empty_narrative = {}
      service = EditorialPolishService.new(empty_narrative, @litellm_client)

      result = service.execute

      assert_equal "", result[:content]
    end

    # Section extraction
    test "execute extracts sections from markdown headers" do
      summaries = [
        { theme: "AI", content: "Content" },
        { theme: "Security", content: "Content" }
      ]

      service = EditorialPolishService.with_full_context(summaries, nil, @narrative, @litellm_client)

      result = service.execute

      sections = result[:sections]
      # Should have at least The Big Picture + AI + Security + Looking Ahead = 4 sections
      assert sections.length >= 3, "Expected at least 3 sections, got #{sections.length}"

      # Check section structure
      first_section = sections.first
      assert first_section["title"].present?
      assert first_section["anchor"].present?
      assert_equal 2, first_section["level"]
      assert first_section["index"].is_a?(Integer)
    end

    test "extract_sections creates URL-safe anchors" do
      content = "## AI & Machine Learning\n## Web Development (2024)\n## Test: Special!"
      sections = @service.send(:extract_sections, content)

      assert_equal "ai-machine-learning", sections[0]["anchor"]
      assert_equal "web-development-2024", sections[1]["anchor"]
      assert_equal "test-special", sections[2]["anchor"]
    end

    # Setters
    test "setter methods allow setting summaries and trends after initialization" do
      service = EditorialPolishService.new(@narrative, @litellm_client)

      summaries = [ { theme: "AI", content: "Content" } ]
      trends = { content: "Trends" }

      service.summaries = summaries
      service.trends = trends

      assert_equal summaries, service.instance_variable_get(:@summaries)
      assert_equal trends, service.instance_variable_get(:@trends)
    end

    # Edge cases
    test "execute handles empty summaries array" do
      service = EditorialPolishService.with_full_context([], nil, @narrative, @litellm_client)

      result = service.execute

      assert_includes result[:content], "Daily Tech Digest"
      # Should still have opening and closing
      assert_includes result[:content], "Today's tech news is exciting"
      assert_includes result[:content], "Stay tuned for more"
    end

    test "execute handles missing opening or closing" do
      incomplete_narrative = { transitions: {} }
      summaries = [ { theme: "AI", content: "Content" } ]

      service = EditorialPolishService.with_full_context(summaries, nil, incomplete_narrative, @litellm_client)

      result = service.execute

      # Should handle gracefully
      assert_includes result[:content], "## The Big Picture"
      assert_includes result[:content], "## Looking Ahead"
    end

    test "execute handles transition not found for theme" do
      incomplete_transitions = { transitions: {} }
      summaries = [ { theme: "AI", content: "Content" } ]

      service = EditorialPolishService.with_full_context(summaries, nil, incomplete_transitions, @litellm_client)

      result = service.execute

      # Should still work without transition
      assert_includes result[:content], "## AI"
    end

    test "with_full_context class method creates service with full context" do
      summaries = [ { theme: "AI", content: "Content" } ]
      trends = { content: "Trends" }

      service = EditorialPolishService.with_full_context(summaries, trends, @narrative, @litellm_client)

      assert_equal summaries, service.instance_variable_get(:@summaries)
      assert_equal trends, service.instance_variable_get(:@trends)
    end
  end
end

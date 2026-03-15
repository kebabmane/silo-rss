module Digest
  class TrendAnalysisService
    def initialize(summaries, litellm_client)
      @summaries = summaries
      @litellm_client = litellm_client
    end

    def execute
      return default_trends if @summaries.blank? || @summaries.count < 2

      prompt = build_prompt
      content = @litellm_client.generate_summary(prompt, max_tokens: 800, temperature: 0.7)

      {
        content: content,
        themes_analyzed: @summaries.map { |s| s[:theme] }
      }
    end

    private

    def build_prompt
      summaries_text = @summaries.map do |summary|
        <<~SUMMARY
          ## #{summary[:theme]}
          #{summary[:content]}
        SUMMARY
      end.join("\n---\n\n")

      <<~PROMPT
        You are a tech industry analyst with deep expertise across multiple domains.

        Review these thematic summaries from today's tech news:

        #{summaries_text}

        TASK: Identify cross-cutting trends and connections across these themes.

        Write 300-400 words of trend analysis that:

        1. **Identifies 2-3 major patterns** you see emerging across multiple themes
           - What common threads connect different stories?
           - Are there broader industry movements visible?

        2. **Makes non-obvious connections** between seemingly separate stories
           - How might developments in one area affect another?
           - What's the bigger picture these stories paint together?

        3. **Provides forward-looking insight**
           - What do these developments collectively signal?
           - What should readers watch for in coming weeks?

        FORMAT:
        - Use markdown with clear section headers
        - Be specific - name companies, technologies, trends
        - Write analytically, not descriptively
        - Avoid restating what's in the summaries; add new insight

        Think like a strategist advising a tech executive on what matters today.
      PROMPT
    end

    def default_trends
      {
        content: "_Trend analysis requires multiple themes to identify patterns._",
        themes_analyzed: @summaries.map { |s| s[:theme] }
      }
    end
  end
end

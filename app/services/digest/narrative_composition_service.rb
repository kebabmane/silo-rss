module Digest
  class NarrativeCompositionService
    def initialize(summaries, trends, litellm_client)
      @summaries = summaries
      @trends = trends
      @litellm_client = litellm_client
    end

    def execute
      prompt = build_prompt
      content = @litellm_client.generate_summary(prompt, max_tokens: 1000, temperature: 0.7)

      {
        opening: extract_section(content, "opening"),
        transitions: extract_transitions(content),
        closing: extract_section(content, "closing"),
        raw_content: content
      }
    end

    private

    def build_prompt
      themes_list = @summaries.map { |s| "- #{s[:theme]}" }.join("\n")

      summaries_preview = @summaries.map do |s|
        "**#{s[:theme]}**: #{truncate(s[:content], 300)}"
      end.join("\n\n")

      <<~PROMPT
        You are the editor of a premier tech newsletter read by founders, engineers, and executives.

        Today's themes:
        #{themes_list}

        Summary previews:
        #{summaries_preview}

        Trend analysis:
        #{@trends[:content]}

        TASK: Write the narrative framing for today's Daily Tech Digest.

        Create THREE sections:

        ## OPENING: "The Big Picture" (150-200 words)
        - What's THE story of tech today?
        - Set the scene for readers: what matters and why
        - Be bold - take a stance on what's significant
        - Write like you're briefing a busy executive

        ## TRANSITIONS (one sentence each)
        For each theme, write a transition sentence that:
        - Connects to the previous section's ideas
        - Introduces the new theme engagingly
        - Maintains narrative flow

        Format as:
        TRANSITION_[THEME_NAME]: Your transition sentence here.

        ## CLOSING: "Looking Ahead" (100-150 words)
        - What should readers watch for?
        - Key questions the day's news raises
        - Forward-looking perspective
        - End with something memorable

        STYLE:
        - Authoritative but accessible
        - Specific, not generic
        - Engaging, not dry
        - Brief but substantive
      PROMPT
    end

    def extract_section(content, type)
      case type
      when "opening"
        # Try to find content between "Big Picture" and "TRANSITION"
        match = content.match(/(?:Big Picture|OPENING)[:\s]*\n*([\s\S]*?)(?=\n*(?:##|TRANSITION|CLOSING|Looking Ahead))/i)
        match ? clean_text(match[1]) : default_opening
      when "closing"
        # Try to find content after "Looking Ahead" or "CLOSING"
        match = content.match(/(?:Looking Ahead|CLOSING)[:\s]*\n*([\s\S]*?)$/i)
        match ? clean_text(match[1]) : default_closing
      end
    end

    def extract_transitions(content)
      transitions = {}

      @summaries.each do |summary|
        theme = summary[:theme]
        # Look for TRANSITION_[THEME] pattern
        pattern = /TRANSITION_#{Regexp.escape(theme)}[:\s]*(.*?)(?:\n|$)/i
        match = content.match(pattern)

        if match
          transitions[theme] = clean_text(match[1])
        else
          # Fallback: generate a simple transition
          transitions[theme] = "Meanwhile, in #{theme.downcase}..."
        end
      end

      transitions
    end

    def clean_text(text)
      text.to_s.strip.gsub(/^\*+|\*+$/, "").strip
    end

    def truncate(text, length)
      return "" if text.blank?
      text.length > length ? "#{text[0...length]}..." : text
    end

    def default_opening
      "Today brings significant developments across the tech landscape."
    end

    def default_closing
      "Stay tuned for tomorrow's digest as these stories continue to evolve."
    end
  end
end

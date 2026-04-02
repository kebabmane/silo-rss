module Digest
  class EditorialPolishService
    def initialize(narrative, litellm_client)
      @narrative = narrative
      @litellm_client = litellm_client
      @summaries = narrative[:summaries] if narrative.is_a?(Hash) && narrative[:summaries]
    end

    # This service can be called with just narrative data or with full context
    def self.with_full_context(summaries, trends, narrative, litellm_client)
      service = new(narrative, litellm_client)
      service.instance_variable_set(:@summaries, summaries)
      service.instance_variable_set(:@trends, trends)
      service
    end

    def execute
      # If we have summaries, assemble the full document first
      if @summaries
        assembled = assemble_document
        polished = polish_document(assembled)
      else
        # Just polish what we have
        polished = @narrative[:raw_content] || ""
      end

      sections = extract_sections(polished)

      {
        content: polished,
        sections: sections
      }
    end

    # Allow setting summaries and trends after initialization
    attr_writer :summaries, :trends

    private

    def assemble_document
      opening = @narrative[:opening] || ""
      closing = @narrative[:closing] || ""
      transitions = @narrative[:transitions] || {}

      parts = []

      # Opening section
      parts << "# Daily Tech Digest"
      parts << ""
      parts << "## The Big Picture"
      parts << ""
      parts << opening
      parts << ""

      # Theme sections with transitions
      @summaries.each_with_index do |summary, idx|
        theme = summary[:theme]
        transition = transitions[theme]

        parts << "---"
        parts << ""

        if transition.present? && idx > 0
          parts << "_#{transition}_"
          parts << ""
        end

        parts << "## #{theme}"
        parts << ""
        parts << summary[:content]
        parts << ""
      end

      # Trends section
      if @trends && @trends[:content].present?
        parts << "---"
        parts << ""
        parts << "## Connecting the Dots"
        parts << ""
        parts << @trends[:content]
        parts << ""
      end

      # Closing section
      parts << "---"
      parts << ""
      parts << "## Looking Ahead"
      parts << ""
      parts << closing

      parts.join("\n")
    end

    def polish_document(content)
      # For now, return the assembled content
      # In future, could send to LLM for final polish
      # but this adds cost and latency with diminishing returns

      content
    end

    def extract_sections(content)
      sections = []

      # Find all h2 headers - scan line by line for markdown headers
      content.to_s.each_line do |line|
        if line =~ /^## (.+)$/
          title = $1.strip
          anchor = title.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")
          sections << {
            "title" => title,
            "anchor" => anchor,
            "level" => 2,
            "index" => sections.length
          }
        end
      end

      sections
    end
  end
end

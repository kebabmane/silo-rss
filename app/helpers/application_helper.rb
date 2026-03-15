require 'redcarpet'

module ApplicationHelper
  def markdown(text)
    return "" if text.blank?

    options = {
      filter_html: false,
      hard_wrap: true,
      link_attributes: { target: "_blank", rel: "noopener noreferrer" },
      space_after_headers: true,
      fenced_code_blocks: true
    }

    extensions = {
      autolink: true,
      superscript: true,
      disable_indented_code_blocks: false,
      fenced_code_blocks: true,
      lax_spacing: true,
      no_intra_emphasis: true,
      strikethrough: true,
      tables: true
    }

    renderer = Redcarpet::Render::HTML.new(options)
    markdown = Redcarpet::Markdown.new(renderer, extensions)

    markdown.render(text).html_safe
  end

  def format_user_time(time, style: :long)
    return "" if time.blank?

    local_time = time.in_time_zone(Time.zone)

    case style
    when :short_date
      local_time.strftime("%b %d, %Y")
    when :long_date
      local_time.strftime("%B %d, %Y")
    when :long
      local_time.strftime("%B %d, %Y at %I:%M %p")
    when :month_day_time
      local_time.strftime("%B %d at %I:%M %p")
    when :relative
      time_ago_in_words(time)
    else
      local_time.to_s
    end
  end

  def relative_time(time)
    return "" if time.blank?
    "#{time_ago_in_words(time)} ago"
  end

  def truncate_html(text, length = 150)
    return "" if text.blank?

    # Remove HTML tags for preview
    clean_text = text.gsub(/<[^>]*>/, '')
    # Truncate and add ellipsis if needed
    if clean_text.length > length
      clean_text[0...length].sub(/\s+\S*\z/, '') + '...'
    else
      clean_text
    end
  end
end

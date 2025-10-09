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
    else
      local_time.to_s
    end
  end
end

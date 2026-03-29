# frozen_string_literal: true

require "kramdown"

module MarkdownHelper
  def md_to_html(text)
    return if text.blank?

    Kramdown::Document.new(text).to_html.html_safe
  end

  def md_to_html_inline(text)
    return if text.blank?

    html = Kramdown::Document.new(text).to_html.strip
    html = html.delete_prefix("<p>").chomp("</p>") if html.start_with?("<p>")
    html.html_safe
  end
end

# frozen_string_literal: true

require "kramdown"

module MarkdownHelper
  def md_to_html(text)
    return if text.blank?

    Kramdown::Document.new(text).to_html.html_safe
  end
end

# frozen_string_literal: true

require "kramdown"

module MarkdownHelper
  def md_to_html(text)
    Kramdown::Document.new(text).to_html.html_safe
  end
end

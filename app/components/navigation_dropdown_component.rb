# frozen_string_literal: true

class NavigationDropdownComponent < ViewComponent::Base
  def initialize(name:, text:, links:, css_class: nil)
    @name = name.underscore
    @text = text
    @links = links
    @css_class = css_class.presence ||
      "focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-offset-red-100 focus:ring-brand font-medium hover:bg-red-700 hover:text-white inline-flex items-center justify-center px-3 py-2 rounded-md text-gray-300 text-sm w-full"
  end
end

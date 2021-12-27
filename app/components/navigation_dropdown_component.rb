# frozen_string_literal: true

class NavigationDropdownComponent < ViewComponent::Base
  def initialize(name:, text:, links:)
    @name = name.underscore
    @text = text
    @links = links
  end
end

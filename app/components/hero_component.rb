# frozen_string_literal: true

class HeroComponent < ViewComponent::Base
  def initialize(cup:, current_user: nil)
    @cup = cup
    @current_user = current_user
  end
end

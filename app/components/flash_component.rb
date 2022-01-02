# frozen_string_literal: true

class FlashComponent < ViewComponent::Base
  def initialize(type:, text:)
    @color = color(type)
    @text = text
  end

  def color(type)
    case type.to_sym
    when :notice, :success
      "green"
    when :info
      "blue"
    when :warning
      "yellow"
    when :alert, :danger, :error
      "red"
    end
  end
end

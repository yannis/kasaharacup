# frozen_string_literal: true

class FlashComponent < ViewComponent::Base
  def initialize(type:, text:)
    @text = text
    @color = color(type)
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

# keep this for tailwind styles
#
# bg-green-50
# bg-green-100
# offset-green-50
# ring-green-600
# text-green-400
# text-green-500
# text-green-800

# bg-blue-50
# bg-blue-100
# offset-blue-50
# ring-blue-600
# text-blue-400
# text-blue-500
# text-blue-800

# bg-yellow-50
# bg-yellow-100
# offset-yellow-50
# ring-yellow-600
# text-yellow-400
# text-yellow-500
# text-yellow-800

# bg-red-50
# bg-red-100
# offset-red-50
# ring-red-600
# text-red-400
# text-red-500
# text-red-800

# p-4

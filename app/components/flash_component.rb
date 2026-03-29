# frozen_string_literal: true

class FlashComponent < ViewComponent::Base
  COLOR_CLASSES = {
    "green" => {
      bg: "bg-green-50",
      icon: "text-green-400",
      text: "text-green-800",
      button: "inline-flex bg-green-50 rounded-md p-1.5 text-green-500 hover:bg-green-100 " \
              "focus:outline-hidden focus:ring-2 focus:ring-offset-2 focus:ring-offset-green-50 focus:ring-green-600"
    },
    "blue" => {
      bg: "bg-blue-50",
      icon: "text-blue-400",
      text: "text-blue-800",
      button: "inline-flex bg-blue-50 rounded-md p-1.5 text-blue-500 hover:bg-blue-100 " \
              "focus:outline-hidden focus:ring-2 focus:ring-offset-2 focus:ring-offset-blue-50 focus:ring-blue-600"
    },
    "yellow" => {
      bg: "bg-yellow-50",
      icon: "text-yellow-400",
      text: "text-yellow-800",
      button: "inline-flex bg-yellow-50 rounded-md p-1.5 text-yellow-500 hover:bg-yellow-100 " \
              "focus:outline-hidden focus:ring-2 focus:ring-offset-2 focus:ring-offset-yellow-50 focus:ring-yellow-600"
    },
    "red" => {
      bg: "bg-red-50",
      icon: "text-red-400",
      text: "text-red-800",
      button: "inline-flex bg-red-50 rounded-md p-1.5 text-red-500 hover:bg-red-100 " \
              "focus:outline-hidden focus:ring-2 focus:ring-offset-2 focus:ring-offset-red-50 focus:ring-red-600"
    }
  }.freeze

  def initialize(type:, text:)
    @text = text
    @color = color(type)
    classes = COLOR_CLASSES.fetch(@color)
    @bg_class = classes[:bg]
    @icon_class = classes[:icon]
    @text_class = classes[:text]
    @button_class = classes[:button]
  end

  private def color(type)
    case type.to_sym
    when :notice, :success then "green"
    when :info then "blue"
    when :warning then "yellow"
    when :alert, :danger, :error then "red"
    end
  end
end

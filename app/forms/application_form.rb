# frozen_string_literal: true

class ApplicationForm
  include ActiveModel::Model

  private def promote_errors(item)
    item.errors.each do |error|
      message = ["#{item.class.to_s.humanize}:"]
      message << item.class.human_attribute_name(error.attribute) if error.attribute != :base
      message << error.message
      errors.add(:base, message.join(" "))
    end
  end
end

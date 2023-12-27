# frozen_string_literal: true

module Translate
  def translate(*attributes)
    attributes.each do |a|
      define_method a.to_s do
        if I18n.locale.to_s == "fr"
          public_send(:"#{a}_fr").presence || public_send(:"#{a}_en")
        elsif I18n.locale.to_s == "de"
          public_send(:"#{a}_de").presence || public_send(:"#{a}_en")
        else
          public_send(:"#{a}_en")
        end
      end
    end
  end
end

ActiveSupport.on_load(:active_record) { extend Translate }

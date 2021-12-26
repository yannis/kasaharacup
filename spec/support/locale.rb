# frozen_string_literal: true

RSpec.configure do |config|
  I18n.available_locales.each do |locale|
    config.around(:each, locale.to_s.underscore.to_sym) do |example|
      I18n.with_locale(locale) do
        example.run
      end
    end
  end
end

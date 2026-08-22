# frozen_string_literal: true

RSpec.configure do |config|
  I18n.available_locales.each do |locale|
    config.around(:each, locale.to_s.underscore.to_sym) do |example|
      I18n.with_locale(locale) do
        example.run
      end
    end
  end

  # HasLocale#set_locale assigns I18n.locale in a before_action, which leaks
  # across examples in-process: a request spec hitting an /en/ URL would leave
  # English messages for later examples that expect the French default.
  config.after do
    I18n.locale = I18n.default_locale # rubocop:disable Rails/I18nLocaleAssignment
  end
end

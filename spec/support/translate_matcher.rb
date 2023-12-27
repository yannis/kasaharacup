# frozen_string_literal: true

require "rspec/expectations"
RSpec::Matchers.define(:translate) do |attribute|
  match do |actual|
    actual.respond_to?(attribute) &
      I18n.available_locales.all? do |locale|
        actual.respond_to?(:"#{attribute}_#{locale}")
      end &
      !actual.respond_to?(:"#{attribute}_unexpected")
  end
end

# frozen_string_literal: true

Rails.application.routes.default_url_options = {
  locale: I18n.default_locale,
  protocol: ENV.fetch("APP_PROTOCOL", "http"),
  host: ENV["APP_HOST"],
  port: ENV.fetch("APP_PORT", 80)
}

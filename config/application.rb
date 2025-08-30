# frozen_string_literal: true

require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Kasaharacup
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # I18n
    config.i18n.available_locales = %i[en fr]
    config.i18n.default_locale = :fr

    # ViewComponent config
    config.view_component.previews.paths << Rails.root.join("lib/component_previews")
    config.view_component.previews.route = "/styleguide/components"

    config.active_record.encryption.primary_key = ENV.fetch("ENCRYPTION_PRIMARY_KEY")
    config.active_record.encryption.deterministic_key = ENV.fetch("ENCRYPTION_DETERMINISTIC_KEY")
    config.active_record.encryption.key_derivation_salt = ENV.fetch("ENCRYPTION_KEY_DERIVATION_SALT")

    Rails.application.routes.default_url_options = {
      protocol: ENV.fetch("APP_PROTOCOL", "http"),
      host: ENV.fetch("APP_HOST"),
      port: ENV.fetch("APP_PORT", 80)
    }

    # Don't generate system test files.
    config.generators do |g|
      g.system_tests = nil
      g.test_framework :rspec, fixture: true
      g.fixture_replacement :factory_bot, dir: "spec/factories"
    end
  end
end

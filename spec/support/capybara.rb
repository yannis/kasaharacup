# frozen_string_literal: true

Capybara.register_driver(:selenium_chrome_container) do |app|
  # Use ignore-certificate-errors to avoid SSL errors as we are using a self-signed certificate
  options = Selenium::WebDriver::Chrome::Options.new(
    args: %w[window-size=1024,768 ignore-certificate-errors]
  )
  Capybara::Selenium::Driver.new(
    app,
    browser: :remote,
    url: "http://#{ENV["SELENIUM_REMOTE_HOST"]}:4444/wd/hub",
    capabilities: options
  )
end

Capybara.register_driver(:selenium_chrome_headless_container) do |app|
  options = Selenium::WebDriver::Chrome::Options.new(
    args: %w[headless disable-gpu no-sandbox window-size=1024,768 ignore-certificate-errors]
  )
  Capybara::Selenium::Driver.new(
    app,
    browser: :remote,
    url: "http://#{ENV["SELENIUM_REMOTE_HOST"]}:4444/wd/hub",
    capabilities: options
  )
end

RSpec.configure do |config|
  config.before(:each, type: :system) do
    headless = ActiveModel::Type::Boolean.new.cast(ENV.fetch("HEADLESS_TEST", "true"))
    if ENV["SELENIUM_REMOTE_HOST"].present?
      driven_by headless ? :selenium_chrome_headless_container : :selenium_chrome_container

      port = 4000 + ENV["TEST_ENV_NUMBER"].to_i
      Capybara.server_host = "0.0.0.0"
      Capybara.server_port = port
      Capybara.app_host = "https://host.docker.internal:#{port}"
    else
      # `selenium_chrome_headless` and `selenium_chrome` are defined in
      # the Capybara gem: /lib/capybara/registrations/drivers.rb
      protocol = ENV.fetch("APP_PROTOCOL", "http")
      host = ENV.fetch("APP_HOST", "localhost")
      port = ENV.fetch("APP_PORT", 80).to_i + ENV["TEST_ENV_NUMBER"].to_i

      Capybara.server_host = host
      Capybara.server_port = port
      Capybara.app_host = "#{protocol}://#{host}:#{port}"
      driven_by headless ? :selenium_chrome_headless : :selenium_chrome
    end
  end
end

Capybara.disable_animation = true
Capybara.default_max_wait_time = 5

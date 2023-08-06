# frozen_string_literal: true

Capybara.register_driver(:selenium_chrome_container) do |app|
  options = Selenium::WebDriver::Chrome::Options.new(
    args: %w[]
  )

  Capybara::Selenium::Driver.new(
    app,
    browser: :remote,
    url: "http://#{ENV["SELENIUM_REMOTE_HOST"]}:4444/wd/hub",
    options: options
  )
end

Capybara.register_driver(:selenium_chrome_headless_container) do |app|
  options = Selenium::WebDriver::Chrome::Options.new(
    args: %w[headless disable-gpu no-sandbox window-size=1680,1050]
  )

  Capybara::Selenium::Driver.new(
    app,
    browser: :remote,
    url: "http://#{ENV["SELENIUM_REMOTE_HOST"]}:4444/wd/hub",
    options: options
  )
end

RSpec.configure do |config|
  config.before(:each, type: :system) do
    headless = ActiveModel::Type::Boolean.new.cast(ENV.fetch("HEADLESS_TEST", "true"))
    if ENV["SELENIUM_REMOTE_HOST"].present?
      driven_by headless ? :selenium_chrome_headless_container : :selenium_chrome_container

      host = `/sbin/ip route show | grep eth0 | awk '/scope/ { print $9 }'`.strip.presence || "0.0.0.0"
      port = 4000 + ENV["TEST_ENV_NUMBER"].to_i
      Capybara.server_host = "0.0.0.0"
      Capybara.server_port = port
      Capybara.app_host = "http://#{host}:#{port}"
    else
      driven_by headless ? :selenium_chrome_headless : :selenium_chrome
    end
  end
end

# frozen_string_literal: true

require "webmock/rspec"

RSpec.configure do |config|
  config.before do
    # No network activity allowed but we still allow download
    # of updated chromedriver if needed (useful for system tests in docker)
    WebMock.disable_net_connect!(
      allow_localhost: true,
      allow: [
        "chromedriver.storage.googleapis.com",
        "googlechromelabs.github.io",
        "edgedl.me.gvt1.com",
        ENV["SELENIUM_REMOTE_HOST"]
      ].compact
    )

    # Slack Notifications
    stub_request(:post, ENV.fetch("SLACK_WEBHOOK"))
      .to_return(status: 200, body: "", headers: {})
  end
end

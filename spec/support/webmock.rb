# frozen_string_literal: true

require "webmock/rspec"

RSpec.configure do |config|
  config.before do
    # Slack Notifications
    stub_request(:post, ENV.fetch("SLACK_WEBHOOK"))
      .to_return(status: 200, body: "", headers: {})
  end
end

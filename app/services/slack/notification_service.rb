# frozen_string_literal: true

module Slack
  class NotificationService
    def call(notification:)
      HTTParty.post(
        ENV.fetch("SLACK_WEBHOOK"),
        body: notification.message.to_json,
        headers: {"Content-Type" => "application/json"}
      )
    end
  end
end

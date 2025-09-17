# frozen_string_literal: true

module Slack
  class NotificationService
    def call(notification:)
      return if ENV.fetch("SLACK_WEBHOOK", nil).blank?

      HTTParty.post(
        ENV.fetch("SLACK_WEBHOOK"),
        body: notification.message.to_json,
        headers: {"Content-Type" => "application/json"}
      )
    end
  end
end

# frozen_string_literal: true

module Slack
  module Notifications
    class Registration
      include Rails.application.routes.url_helpers

      def initialize(kenshi)
        @kenshi = kenshi
      end

      def message
        {
          blocks: [
            {
              type: "header",
              text: {
                type: "plain_text",
                text: "New Kenshi",
                emoji: true
              }
            },
            {
              type: "section",
              fields: [
                {
                  type: "mrkdwn",
                  text: "*Name:*\n<#{cup_kenshi_url(@kenshi.cup, @kenshi,
                    locale: I18n.locale)}|#{@kenshi.full_name}>"
                },
                {
                  type: "mrkdwn",
                  text: "*Environment:*\n#{ENV.fetch("ENVIRONMENT")}"
                }
              ]
            },
            {
              type: "section",
              fields: [
                {
                  type: "mrkdwn",
                  text: "*Registered by:*\n#{@kenshi.user.full_name}"
                }
              ]
            },
            {
              type: "section",
              fields: [
                {
                  type: "mrkdwn",
                  text: "*Registered by:*\n#{I18n.l(@kenshi.created_at.in_time_zone("Bern"), format: :long)}"
                }
              ]
            }
          ]
        }
      end
    end
  end
end

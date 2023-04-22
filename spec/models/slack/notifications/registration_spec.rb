# frozen_string_literal: true

require "rails_helper"

describe(Slack::Notifications::Registration) do
  let(:cup) { build(:cup, year: 2022) }
  let(:user) { build(:user, first_name: "Dave", last_name: "McEnzie") }
  let!(:kenshi) { create(:kenshi, first_name: "Akira", last_name: "Yoshimura", user: user, cup: cup) }
  let(:notification) { described_class.new(kenshi) }

  it do
    expect(notification.message).to eq(blocks: [
      {text: {emoji: true, text: "New Kenshi", type: "plain_text"},
       type: "header"}, {fields: [{text: "*Name:*\n<http://localhost:3000/fr/cups/2022/kenshis/#{kenshi.id}|Akira Yoshimura>", type: "mrkdwn"}, {text: "*Environment:*\n#{ENV.fetch("ENVIRONMENT")}", type: "mrkdwn"}], type: "section"}, {fields: [{text: "*Registered by:*\nM. Dave Mcenzie", type: "mrkdwn"}], type: "section"}, {fields: [{text: "*Registered by:*\n#{I18n.l(kenshi.created_at.in_time_zone("Bern"), format: :long)}", type: "mrkdwn"}], type: "section"}
    ])
  end
end

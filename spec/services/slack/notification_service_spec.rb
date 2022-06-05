# frozen_string_literal: true

require "rails_helper"

describe(Slack::NotificationService) do
  let!(:kenshi) { build_stubbed(:kenshi) }
  let(:notification) { Slack::Notifications::Registration.new(kenshi) }
  let(:service) { described_class.new }

  describe "#call" do
    context "when success" do
      before do
        allow(HTTParty).to receive(:post).and_return(Struct.new(:parsed_response).new("ok"))
      end

      it { expect(service.call(notification: notification).parsed_response).to eq("ok") }
    end
  end
end

# frozen_string_literal: true

require "rails_helper"

# Issue #1296 was a production-only Action Cable outage: the configured adapter
# could not load at all, and a fully green suite never saw it because `test:`
# names a different adapter. These specs close that blind spot — they resolve
# every environment's adapter the way Action Cable does at boot, and exercise
# the gem's own queries against the schema our migration created.
RSpec.describe "Action Cable configuration" do # rubocop:disable RSpec/DescribeClass
  def cable_config_for(environment)
    Rails.application.config_for(:cable, env: environment)
  end

  # Mirrors ActionCable::Server::Configuration#pubsub_adapter.
  def pubsub_adapter_for(environment)
    adapter = cable_config_for(environment).fetch(:adapter)
    require "action_cable/subscription_adapter/#{adapter}"
    ActionCable::SubscriptionAdapter.const_get(adapter.camelize)
  end

  %w[development test production].each do |environment|
    it "resolves the #{environment} pubsub adapter" do
      expect(pubsub_adapter_for(environment)).to be < ActionCable::SubscriptionAdapter::Base
    end
  end

  it "runs the same adapter in development as in production" do
    expect(cable_config_for("development").fetch(:adapter))
      .to eq cable_config_for("production").fetch(:adapter)
  end

  describe "the production adapter's settings" do
    subject(:config) { cable_config_for("production") }

    # Left to the gem, each of these would change under us on a version bump.
    it "spells out every value rather than inheriting a gem default" do
      expect(config).to include(
        polling_interval: "0.1.seconds",
        message_retention: "5.minutes"
      )
    end

    # The gem's default of 1 lets a single ConnectionTimeoutError kill the
    # listener thread silently and permanently.
    it "retries a dropped connection more than once, with backoff" do
      expect(config.fetch(:reconnect_attempts)).to be_an(Array)
      expect(config.fetch(:reconnect_attempts).size).to be > 1
      expect(config.fetch(:reconnect_attempts)).to all(be_positive)
    end
  end

  # The table is a hand-written migration rather than the gem's generator, so
  # nothing else would catch a version whose queries expect a different schema.
  describe "the solid_cable_messages schema" do
    it "satisfies the gem's own broadcast and read-back queries" do
      SolidCable::Message.broadcast("kasaharacup:test", "payload")

      messages = SolidCable::Message.broadcastable(["kasaharacup:test"], 0)

      expect(messages.map(&:payload)).to include("payload")
    end

    it "satisfies the gem's trim query" do
      expect { SolidCable::TrimJob.perform_now }.not_to raise_error
    end
  end
end

# frozen_string_literal: true

module Stripe
  class WebhooksController < ApplicationController
    skip_before_action :verify_authenticity_token

    def create
      payload = request.body.read
      event = nil
      endpoint_secret = ENV.fetch("STRIPE_WEBHOOK_SECRET")

      begin
        event = Stripe::Event.construct_from(
          JSON.parse(payload, symbolize_names: true)
        )
      rescue JSON::ParserError => e
        # Invalid payload
        Rails.logger.debug { "⚠️  Webhook error while parsing basic request. #{e.message}" }
        head :unprocessable_entity
        return
      end

      # Retrieve the event by verifying the signature using the raw body and secret.
      signature = request.env["HTTP_STRIPE_SIGNATURE"]
      begin
        event = Stripe::Webhook.construct_event(
          payload, signature, endpoint_secret
        )
      rescue Stripe::SignatureVerificationError => e
        Rails.logger.debug { "⚠️  Webhook signature verification failed. #{e.message}" }
        head :unprocessable_entity
      end
      ::Webhook.create!(stripe_id: event.id, event_type: event.type, payload: JSON.parse(payload))
      head :ok
    end
  end
end

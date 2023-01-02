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
        puts "⚠️  Webhook error while parsing basic request. #{e.message}"
        status 400
        return
      end
      # Check if webhook signing is configured.
      if endpoint_secret
        # Retrieve the event by verifying the signature using the raw body and secret.
        signature = request.env['HTTP_STRIPE_SIGNATURE'];
        begin
          event = Stripe::Webhook.construct_event(
            payload, signature, endpoint_secret
          )
        rescue Stripe::SignatureVerificationError => e
          puts "⚠️  Webhook signature verification failed. #{e.message}"
          status 400
        end
      end

      # Handle the event
      case event.type
      when 'payment_intent.succeeded'
        payment_intent = event.data.object # contains a Stripe::PaymentIntent
        puts "Payment for #{payment_intent['amount']} succeeded."
        # Then define and call a method to handle the successful payment intent.
        # handle_payment_intent_succeeded(payment_intent)
      when 'payment_method.attached'
        payment_method = event.data.object # contains a Stripe::PaymentMethod
        # Then define and call a method to handle the successful attachment of a PaymentMethod.
        # handle_payment_method_attached(payment_method)
      else
        puts "Unhandled event type: #{event.type}"
      end
      render head: :ok
    end
  end
end

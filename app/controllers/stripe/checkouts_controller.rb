# frozen_string_literal: true

module Stripe
  class CheckoutsController < ApplicationController
    before_action :authenticate_user!, :set_cup

    def create
      order = current_user.orders.pending.last
      if order.nil?
        redirect_to(cup_user_url(@cup), alert: "No order to pay for")
      else
        set_customer
        session = Stripe::Checkout::Session.create({
          line_items: current_user.line_items(cup: @cup),
          mode: "payment",
          success_url: success_order_url(order.uuid),
          cancel_url: cancel_order_url(order.uuid),
          customer: @customer.id
        })
        redirect_to(session.url, status: :see_other, allow_other_host: true)
      end
    end

    private def set_customer
      if current_user.stripe_customer_id.nil?
        @customer = Stripe::Customer.create(email: current_user.email)
        current_user.update(stripe_customer_id: @customer.id)
      else
        @customer = Stripe::Customer.retrieve(current_user.stripe_customer_id)
      end
    end

    private def set_cup
      @cup = Cup.find_by(year: params[:cup_id])
    end
  end
end

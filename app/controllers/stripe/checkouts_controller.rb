# frozen_string_literal: true

module Stripe
  class CheckoutsController < ApplicationController
    before_action :authenticate_user!, :set_cup

    def create
      session = Stripe::Checkout::Session.create({
        line_items: current_user.line_items(cup: @cup),
        mode: "payment",
        success_url: cup_user_url(@cup),
        cancel_url: cup_user_url(@cup),
        customer_email: current_user.email
      })
      redirect_to(session.url, status: :see_other, allow_other_host: true)
    end

    private def set_cup
      @cup = Cup.find_by(year: params[:cup_id])
    end
  end
end

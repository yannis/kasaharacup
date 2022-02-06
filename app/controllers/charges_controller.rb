# frozen_string_literal: true

class ChargesController < ApplicationController
  def new
  end

  def create
    # Amount in cents
    @amount = current_user.fees(:chf, current_cup) * 100

    customer = Stripe::Customer.create(
      email: current_user.email,
      card: params[:stripeToken]
    )

    Stripe::Charge.create(
      customer: customer.id,
      amount: @amount,
      description: "Rails Stripe customer",
      currency: "usd"
    )
  rescue Stripe::CardError => e
    flash[:error] = e.message
    redirect_to charges_path
  end
end

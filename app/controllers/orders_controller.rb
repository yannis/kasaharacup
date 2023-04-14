# frozen_string_literal: true

class OrdersController < ApplicationController
  # skip_before_action :authenticate_user!, only: [:show]
  before_action :set_order, only: [:success, :cancel]

  def success
    @order.pay!
    redirect_to(cup_user_url(@order.cup), notice: "Order paid")
  end

  def cancel
    redirect_to(cup_user_url(@order.cup), notice: "Payment cancelled")
  end

  private def set_order
    @order = Order.find_by!(uuid: params[:id])
  end
end

# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action :set_current_cup

  private def set_current_cup
    return if @current_cup.present?

    future_cups = Cup.future.order("cups.start_on ASC")
    past_cups = Cup.past.order("cups.start_on DESC")
    if future_cups.present?
      @current_cup = future_cups.first
    elsif past_cups.present?
      @current_cup = past_cups.first
    else
      raise "Cup is missing!!!"
    end
  end
end

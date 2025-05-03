# frozen_string_literal: true

class CupsController < ApplicationController
  skip_before_action :set_current_cup, only: [:show]

  def index
    @cups = Cup.all
  end

  def show
    @cup = Cup.where("EXTRACT(YEAR FROM cups.start_on) = ?", params[:id]).first
    if @cup.nil?
      set_current_cup
      redirect_to cup_path(@current_cup)
    else
      @current_cup = @cup
      @grouped_events = @cup.events.order(:start_on).group_by { |e| e.start_on.to_date }
      @headlines = @cup.headlines.shown.order(created_at: :desc)
      @shinpans = @cup.kenshis.shinpans.includes(:club).order(:last_name, :first_name)
      template = if @cup.canceled?
        "show_canceled"
      elsif Date.current > @cup.start_on.to_date
        "show_past"
      else
        "show"
      end
      render template
    end
  end
end

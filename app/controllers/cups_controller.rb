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
      redirect_to cup_path(@current_cup, locale: I18n.locale)
    else
      @current_cup = @cup
      @grouped_events = @cup.events.order(:start_on).group_by { |e| e.start_on.to_date }
      @headlines = @cup.headlines.shown.order("headlines.created_at DESC")
      if Date.current > @cup.start_on.to_date
        begin
          render "show_past_#{@cup.year.to_i}"
        rescue ActionView::MissingTemplate
          render "show_past"
        end
      else
        render "show"
      end
    end
  end
end

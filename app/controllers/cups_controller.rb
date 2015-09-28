class CupsController < ApplicationController

  skip_before_filter :set_current_cup, only: [:show]

  respond_to :html

  def index
    @cups = Kendocup::Cup.all
  end

  def show
    @cup = Kendocup::Cup.where("extract(year from cups.start_on) = ?", params[:id]).first
    if @cup.nil?
      set_current_cup
      redirect_to cup_path(@current_cup, locale: I18n.locale)
    else
      @current_cup = @cup
      @grouped_events = @cup.events.order(:start_on).group_by{|e| e.start_on.to_date}
      @headline = @cup.headlines.shown.order("headlines.created_at DESC").first
      respond_with @cup do |format|
        format.html {
          if Date.current > @cup.start_on.to_date
            begin
              render "show_past_#{@cup.year.to_i}"
            rescue ActionView::MissingTemplate
              render "show_past"
            end
          else
            render "show"
          end
        }
      end
    end
  end
end

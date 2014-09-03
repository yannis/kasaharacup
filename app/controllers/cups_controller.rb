class CupsController < ApplicationController

  def show
    @grouped_events = @cup.events.order(:start_on).group_by{|e| e.start_on.to_date}
    @headlines = @cup.headlines.shown.order("headlines.created_at DESC")
  end
end

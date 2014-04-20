class CupsController < ApplicationController

  def show
    @grouped_events = @cup.events.order(:start_on).group_by{|e| e.start_on.to_date}
  end
end

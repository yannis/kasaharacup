class HeadlinesController < ApplicationController


  load_and_authorize_resource :cup, find_by: :year, class: Kendocup::Cup
  load_and_authorize_resource :headline, class: Kendocup::Headline, through: [:cup]

  respond_to :html

  def index
    respond_with @headlines.order(created_at: :desc)
  end

  def show
    respond_with @headline
  end
end

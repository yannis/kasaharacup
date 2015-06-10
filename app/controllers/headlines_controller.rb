class HeadlinesController < ApplicationController

  load_and_authorize_resource class: Kendocup::Headline

  respond_to :html

  def index
    respond_with @headlines.order(created_at: :desc)
  end

  def show
    respond_with @headline
  end
end

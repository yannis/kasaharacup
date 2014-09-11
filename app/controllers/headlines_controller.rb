class HeadlinesController < ApplicationController
  load_and_authorize_resource :headline
  respond_to :html

  def index
    respond_with @headlines.order("headlines.created_at DESC")
  end

  def show
    respond_with @headline
  end
end

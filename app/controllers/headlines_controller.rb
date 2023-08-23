# frozen_string_literal: true

class HeadlinesController < ApplicationController
  load_and_authorize_resource :cup, find_by: :year, class: Cup
  load_and_authorize_resource :headline, class: Headline, through: [:cup]

  respond_to :html

  def index
    @headlines = @headlines.order(created_at: :desc)
  end

  def show
    respond_with @headline
  end
end

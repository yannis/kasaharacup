# frozen_string_literal: true

class TermsController < ApplicationController
  skip_before_action :set_current_cup
  load_and_authorize_resource :cup, find_by: :year, class: "Cup"

  def show
    @current_cup = @cup
  end
end

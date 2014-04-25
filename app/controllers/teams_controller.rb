class TeamsController < ApplicationController
  load_and_authorize_resource :team
  respond_to :html

  def index
    respond_with @teams
  end

  def show
    respond_with @team
  end
end

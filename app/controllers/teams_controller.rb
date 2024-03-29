# frozen_string_literal: true

class TeamsController < ApplicationController
  load_and_authorize_resource :cup, find_by: :year, class: Cup
  load_and_authorize_resource :team, class: Team
  respond_to :html

  def index
    @ronins = @cup.participations.ronins.map(&:kenshi)
    @teams = @cup.teams
      .includes(:kenshis, team_category: :cup)
      .joins(:participations)
      .order(:name)
      .distinct
    respond_with @teams
  end

  def show
    @kenshis = @team.kenshis.includes(:user, :club, participations: [:category]).order(:last_name, :first_name)
    respond_with @team
  end
end

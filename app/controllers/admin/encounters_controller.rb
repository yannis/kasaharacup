# frozen_string_literal: true

module Admin
  class EncountersController < BaseController
    before_action :set_team_category

    def show
      @encounter = @team_category.encounters.find(params.expect(:id))
    end

    private def set_team_category
      @team_category = TeamCategory.find(params.expect(:team_category_id))
    end
  end
end

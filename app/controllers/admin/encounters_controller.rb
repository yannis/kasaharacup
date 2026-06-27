# frozen_string_literal: true

module Admin
  class EncountersController < BaseController
    before_action :set_team_category

    def index
      @encounters = @team_category.encounters
        .includes(:team_1, :team_2, :winner,
          parent_encounter_1: :winner, parent_encounter_2: :winner)
        .order(:id)
    end

    def show
      @encounter = @team_category.encounters.find(params.expect(:id))
    end

    def new
    end

    def create
      permitted = params.expect(encounter: [:team_1_id, :team_2_id])
      encounter = @team_category.encounters.create!(permitted)
      redirect_to admin_team_category_encounter_path(@team_category, encounter),
        notice: t(".notice")
    rescue ActiveRecord::RecordInvalid => e
      redirect_to new_admin_team_category_encounter_path(@team_category),
        alert: e.record.errors.full_messages.to_sentence
    end

    private def set_team_category
      @team_category = TeamCategory.find(params.expect(:team_category_id))
    end
  end
end

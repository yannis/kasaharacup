# frozen_string_literal: true

module Admin
  class EncountersController < BaseController
    before_action :set_team_category

    def index
      @encounters = @team_category.encounters.order(:id)
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

    def lineup
      encounter = @team_category.encounters.find(params.expect(:id))
      team = @team_category.teams.find(params.expect(:team_id))
      EncounterLineup.new(encounter).assign(team, lineup_kenshi_ids)
      respond_with_encounter(encounter, notice: t(".notice"))
    rescue EncounterLineup::InvalidLineup => e
      flash.now[:alert] = e.message
      respond_with_encounter(encounter)
    end

    def daihyosen
      encounter = @team_category.encounters.find(params.expect(:id))
      encounter.team_fights.create!(
        daihyosen: true,
        position: encounter.team_size + 1,
        kenshi_1_id: params.expect(:kenshi_1_id),
        kenshi_2_id: params.expect(:kenshi_2_id)
      )
      respond_with_encounter(encounter, notice: t(".notice"))
    rescue ActiveRecord::RecordInvalid => e
      # A second daihyōsen collides with the unique [encounter_id, position]
      # index; a missing rep fails the not-null kenshi. Surface it, don't 500.
      flash.now[:alert] = e.record.errors.full_messages.to_sentence
      respond_with_encounter(encounter)
    end

    def swap_team
      encounter = @team_category.encounters.find(params.expect(:id))
      team = @team_category.teams.find(params.expect(:team_id))
      EncounterTeamSwap.new(encounter).swap(params.expect(:slot).to_i, team)
      redirect_to admin_team_category_path(@team_category), notice: t(".notice")
    rescue EncounterTeamSwap::InvalidSwap => e
      redirect_to admin_team_category_path(@team_category), alert: e.message
    end

    # The lineup form selects use include_blank, so unselected (forfeit) positions
    # arrive as empty strings; drop them so a short lineup is treated as trailing
    # forfeits rather than failing the team-membership check on a "0" id.
    private def lineup_kenshi_ids
      Array(params[:kenshi_ids]).compact_blank
    end

    private def set_team_category
      @team_category = TeamCategory.find(params.expect(:team_category_id))
    end
  end
end

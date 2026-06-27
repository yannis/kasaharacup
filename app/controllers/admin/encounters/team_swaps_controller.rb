# frozen_string_literal: true

module Admin
  module Encounters
    # Swaps a bracket-only round-1 slot's occupant with another round-1 team —
    # the admin's draw-correction tool (see EncounterTeamSwap for the rules).
    class TeamSwapsController < Admin::BaseController
      def create
        team = team_category.teams.find(params.expect(:team_id))
        EncounterTeamSwap.new(encounter).swap(params.expect(:slot).to_i, team)
        redirect_to admin_team_category_path(team_category), notice: t(".notice")
      rescue EncounterTeamSwap::InvalidSwap => e
        redirect_to admin_team_category_path(team_category), alert: e.message
      end
    end
  end
end

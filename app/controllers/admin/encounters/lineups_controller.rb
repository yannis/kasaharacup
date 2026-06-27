# frozen_string_literal: true

module Admin
  module Encounters
    # Replaces one team's fighter order for an encounter. The lineup form sends
    # one value per position in order, so the array index IS the position;
    # unselected (forfeit) slots arrive as empty strings and map to nil, keeping
    # a blank at its position rather than shifting later fighters up.
    class LineupsController < Admin::BaseController
      def update
        team = team_category.teams.find(params.expect(:team_id))
        EncounterLineup.new(encounter).assign(team, lineup_kenshi_ids)
        respond_with_encounter(encounter, notice: t(".notice"))
      rescue EncounterLineup::InvalidLineup => e
        flash.now[:alert] = e.message
        respond_with_encounter(encounter)
      end

      private def lineup_kenshi_ids
        Array(params[:kenshi_ids]).map(&:presence)
      end
    end
  end
end

# frozen_string_literal: true

module Admin
  module Encounters
    # Replaces one team's fighter order for an encounter. The lineup form sends
    # one value per position in order, so the array index IS the position;
    # unselected (forfeit) slots arrive as empty strings and map to nil, keeping
    # a blank at its position rather than shifting later fighters up.
    class LineupsController < Admin::BaseController
      before_action :refuse_when_bracket_frozen

      def update
        team = team_category.teams.find(params.expect(:team_id))
        EncounterLineup.new(encounter).assign(team, lineup_kenshi_ids)
        respond_with_encounter(encounter, notice: t(".notice"))
      rescue EncounterLineup::InvalidLineup => e
        flash.now[:alert] = e.message
        respond_with_encounter(encounter)
      end

      # Serves pool encounters too, so the guard turns on the encounter: a
      # frozen bracket must not stop a pool lineup being set.
      private def refuse_when_bracket_frozen
        guard_frozen_bracket!(team_category) if encounter.bracket?
      end

      private def lineup_kenshi_ids
        Array(params[:kenshi_ids]).map(&:presence)
      end
    end
  end
end

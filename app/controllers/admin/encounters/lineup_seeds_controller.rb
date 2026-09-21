# frozen_string_literal: true

module Admin
  module Encounters
    # Seeds a fresh encounter's unset sides with their suggested order when the
    # admin opens it (POSTed once by the lineup Stimulus controller on connect),
    # then morphs the panel so the populated, draggable bouts appear in place.
    class LineupSeedsController < Admin::BaseController
      before_action :refuse_when_bracket_frozen

      # #encounter and #team_category are Admin::BaseController's shared,
      # memoised finders for the encounter-scoped controllers; the guard below
      # already loads both, so looking the encounter up again here would be a
      # second query for a record already in hand.
      def create
        EncounterLineupSeeder.new(encounter).call
        respond_with_encounter(encounter)
      end

      # Serves pool encounters too, so the guard turns on the encounter.
      private def refuse_when_bracket_frozen
        guard_frozen_bracket!(team_category) if encounter.bracket?
      end
    end
  end
end

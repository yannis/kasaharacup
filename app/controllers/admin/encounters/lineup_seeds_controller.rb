# frozen_string_literal: true

module Admin
  module Encounters
    # Seeds a fresh encounter's unset sides with their suggested order when the
    # admin opens it (POSTed once by the lineup Stimulus controller on connect),
    # then morphs the panel so the populated, draggable bouts appear in place.
    class LineupSeedsController < Admin::BaseController
      before_action :set_team_category

      def create
        encounter = @team_category.encounters.find(params.expect(:encounter_id))
        EncounterLineupSeeder.new(encounter).call
        respond_with_encounter(encounter)
      end

      private def set_team_category
        @team_category = TeamCategory.find(params.expect(:team_category_id))
      end
    end
  end
end

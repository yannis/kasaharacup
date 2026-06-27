# frozen_string_literal: true

module Admin
  # Toggles a regular bout's hikiwake (draw) flag. Eligibility is enforced on the
  # server (TeamFight#hikiwake_eligible?) — the model has no draw validation, so
  # a raw PATCH could otherwise mark a scored/forfeit/decided/unconfirmed bout.
  class TeamFightsController < BaseController
    def update
      return head :unprocessable_content unless team_fight.hikiwake_eligible?

      team_fight.update!(draw: ActiveModel::Type::Boolean.new.cast(draw_param))
      respond_with_encounter(encounter)
    end

    private def draw_param
      params.expect(team_fight: [:draw])[:draw]
    end

    private def team_fight
      @team_fight ||= encounter.team_fights.find(params.expect(:id))
    end
  end
end

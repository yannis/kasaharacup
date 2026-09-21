# frozen_string_literal: true

module Admin
  # Toggles a regular bout's hikiwake (draw) flag. Eligibility is enforced on the
  # server (TeamFight#hikiwake_eligible?) — the model has no draw validation, so
  # a raw PATCH could otherwise mark a scored/forfeit/decided/unconfirmed bout.
  class TeamFightsController < BaseController
    before_action :refuse_when_bracket_frozen

    def update
      return head :unprocessable_content unless team_fight.hikiwake_eligible?

      team_fight.update!(draw: ActiveModel::Type::Boolean.new.cast(draw_param))
      respond_with_encounter(encounter)
    end

    # Serves pool encounters as well as bracket ones, so the guard turns on the
    # encounter: a frozen bracket must not stop the pool phase being recorded.
    private def refuse_when_bracket_frozen
      guard_frozen_bracket!(team_category) if encounter.bracket?
    end

    private def draw_param
      params.expect(team_fight: [:draw])[:draw]
    end

    private def team_fight
      @team_fight ||= encounter.team_fights.find(params.expect(:id))
    end
  end
end

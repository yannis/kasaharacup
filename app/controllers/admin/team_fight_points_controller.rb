# frozen_string_literal: true

module Admin
  class TeamFightPointsController < BaseController
    rescue_from ArgumentError, with: :render_unprocessable
    rescue_from ActiveRecord::RecordInvalid, with: :flash_validation_error

    before_action :refuse_when_bracket_frozen

    def create
      team_fight.with_lock { team_fight.fight_points.create!(point_params) }
      respond_with_encounter(encounter)
    end

    def destroy
      point = team_fight.fight_points.find(params.expect(:id))
      point.destroy!
      respond_with_encounter(encounter)
    end

    # Serves pool encounters as well as bracket ones, so the guard turns on the
    # encounter: a frozen bracket must not stop the pool phase being recorded.
    private def refuse_when_bracket_frozen
      guard_frozen_bracket!(team_category) if encounter.bracket?
    end

    private def team_fight
      @team_fight ||= encounter.team_fights.find(params.expect(:team_fight_id))
    end

    private def point_params
      params.expect(team_fight_point: [:fighter_side, :kind])
    end

    private def flash_validation_error(exception)
      flash.now[:alert] = exception.record.errors.full_messages.to_sentence
      respond_with_encounter(encounter)
    end

    private def render_unprocessable
      head :unprocessable_content
    end
  end
end

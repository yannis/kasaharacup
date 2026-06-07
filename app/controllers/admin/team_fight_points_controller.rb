# frozen_string_literal: true

module Admin
  class TeamFightPointsController < BaseController
    rescue_from ArgumentError, with: :render_unprocessable
    rescue_from ActiveRecord::RecordInvalid, with: :flash_validation_error

    def create
      team_fight.with_lock { team_fight.fight_points.create!(point_params) }
      respond_with_encounter(encounter)
    end

    def destroy
      point = team_fight.fight_points.find(params.expect(:id))
      point.destroy!
      respond_with_encounter(encounter)
    end

    private def team_category
      @team_category ||= TeamCategory.find(params.expect(:team_category_id))
    end

    private def encounter
      @encounter ||= team_category.encounters.find(params.expect(:encounter_id))
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

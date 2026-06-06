# frozen_string_literal: true

module Admin
  class FightPointsController < BaseController
    rescue_from ArgumentError, with: :render_unprocessable
    rescue_from ActiveRecord::RecordInvalid, with: :flash_validation_error

    def create
      fight.with_lock { fight.fight_points.create!(point_params) }
      respond_after_change
    end

    def destroy
      point = fight.fight_points.find(params[:id])
      point.destroy!
      respond_after_change
    end

    private def flash_validation_error(exception)
      flash.now[:alert] = exception.record.errors.full_messages.to_sentence
      respond_after_change
    end

    private def category
      @category ||= IndividualCategory.find(params[:individual_category_id])
    end

    private def fight
      @fight ||= category.fights.find(params[:pool_fight_id] || params[:fight_id])
    end

    private def respond_after_change
      if fight.pool_number.present?
        respond_with_pool(category, fight.pool_number)
      else
        respond_with_tree(category)
      end
    end

    private def point_params
      params.expect(fight_point: [:fighter_side, :kind])
    end

    private def render_unprocessable
      head :unprocessable_content
    end
  end
end

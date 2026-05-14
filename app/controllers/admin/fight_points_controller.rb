# frozen_string_literal: true

module Admin
  class FightPointsController < BaseController
    rescue_from ArgumentError, with: :render_unprocessable

    def create
      category = IndividualCategory.find(params[:individual_category_id])
      fight = category.fights.find(params[:fight_id])
      fight.with_lock { fight.fight_points.create!(point_params) }

      respond_with_tree(category)
    end

    def destroy
      category = IndividualCategory.find(params[:individual_category_id])
      fight = category.fights.find(params[:fight_id])
      point = fight.fight_points.find(params[:id])
      point.destroy!

      respond_with_tree(category)
    end

    private def point_params
      params.expect(fight_point: [:fighter_side, :kind])
    end

    private def render_unprocessable
      head :unprocessable_content
    end
  end
end

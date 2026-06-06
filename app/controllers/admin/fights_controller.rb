# frozen_string_literal: true

module Admin
  class FightsController < BaseController
    def update
      category = IndividualCategory.find(params.expect(:individual_category_id))
      fight = category.fights.find(params.expect(:id))
      winner = fight.fighters.find { |fighter| fighter.id == fight_params[:winner_id].to_i }
      fight.update!(winner: winner)

      respond_with_tree(category, notice: t(".notice"))
    end

    private def fight_params
      params.expect(fight: [:winner_id])
    end
  end
end

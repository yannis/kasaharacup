# frozen_string_literal: true

module Admin
  class FightsController < BaseController
    def update
      category = IndividualCategory.find(params.expect(:individual_category_id))
      fight = category.fights.find(params.expect(:id))
      # This is the bracket's controller, but it looks the fight up in #fights
      # rather than #bracket_fights, so it guards on the predicate — one rule
      # for the pool/bracket split, shared with FightPointsController.
      return if fight.bracket? && guard_frozen_bracket!(category)

      winner = fight.fighters.find { |fighter| fighter.id == fight_params[:winner_id].to_i }
      fight.update!(winner: winner)

      respond_with_tree(category, notice: t(".notice"))
    end

    private def fight_params
      params.expect(fight: [:winner_id])
    end
  end
end

# frozen_string_literal: true

module Admin
  class CompetitionTreesController < BaseController
    def generate_bracket
      category = IndividualCategory.find(params.expect(:id))
      # Generate, update and force rebuild all land here; a frozen tree refuses
      # all three. In-action, so the return is what halts it.
      return if guard_frozen_bracket!(category)

      IndividualCategoryBracketBuilder.new(category, rebuild_started: truthy_param?(:rebuild_started)).call
      redirect_to admin_individual_category_path(category), notice: t(".notice")
    end

    private def truthy_param?(key)
      ActiveModel::Type::Boolean.new.cast(params[key])
    end
  end
end

# frozen_string_literal: true

module Admin
  class CompetitionTreesController < BaseController
    def generate_bracket
      category = IndividualCategory.find(params[:id])
      IndividualCategoryBracketBuilder.new(category, rebuild_started: truthy_param?(:rebuild_started)).call
      redirect_to admin_individual_category_path(category), notice: t(".notice")
    end

    private def truthy_param?(key)
      ActiveModel::Type::Boolean.new.cast(params[key])
    end
  end
end

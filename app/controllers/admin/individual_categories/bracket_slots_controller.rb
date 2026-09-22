# frozen_string_literal: true

module Admin
  module IndividualCategories
    # A round-1 fight slot. See Admin::BracketSlotActions.
    class BracketSlotsController < Admin::BaseController
      include Admin::BracketSlotActions

      private def category
        @category ||= IndividualCategory.find(params.expect(:individual_category_id))
      end

      private def tree_stream
        helpers.turbo_stream.replace(
          helpers.dom_id(category, :competition_tree),
          CompetitionTreeComponent.new(category: category, admin: true),
          method: :morph
        )
      end

      private def broadcast_stream_name = [category, :competition_tree]
    end
  end
end

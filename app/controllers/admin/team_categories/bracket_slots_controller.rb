# frozen_string_literal: true

module Admin
  module TeamCategories
    # A round-1 encounter slot. See Admin::BracketSlotActions for the body and
    # BracketSlotMove for the rules.
    class BracketSlotsController < Admin::BaseController
      include Admin::BracketSlotActions

      private def category = team_category

      private def tree_stream
        helpers.turbo_stream.replace(
          helpers.dom_id(category, :encounter_tree),
          EncounterTreeComponent.new(team_category: category, admin: true),
          method: :morph
        )
      end

      private def broadcast_stream_name = [category, :encounter_tree]
    end
  end
end

# frozen_string_literal: true

module Admin
  module IndividualCategories
    # Seeds a participation of an individual category, reorders the seeds, or
    # unseeds one. The ordering and renumbering live in SeedOrderMove; :id is
    # the participation id, the convention pool_memberships already uses.
    #
    # The response carries more than the panel. A seeded participant already
    # sitting in a pool wears its badge on the pool card and in the tree, so
    # both are replaced too — otherwise they keep the old number until the next
    # full page load.
    #
    # No confirmation/422 flow, unlike
    # Admin::IndividualCategories::PoolMembershipsController: nothing here
    # discards recorded work, so there is nothing to confirm.
    #
    # The change is broadcast the way that sibling broadcasts its own: the pool
    # cards and the tree already subscribe to the category's :competition_tree
    # stream, and seeding is not confined to the quiet hour before the
    # competition — a category can be reseeded once its bracket exists. Without
    # this, a second admin with the page open keeps seed badges that look
    # current and are not. Every stream is a replace, so the acting admin
    # applying them twice — once from the response, once from the broadcast —
    # is idempotent.
    class SeedsController < Admin::BaseController
      def update
        apply(params[:to_position])
      end

      def destroy
        apply(nil)
      end

      # nil unseeds — SeedOrderMove reads a blank target that way.
      private def apply(to_position)
        SeedOrderMove.new(participation: participation, to_position: to_position).call
        broadcast
        render turbo_stream: streams
      end

      private def broadcast
        Turbo::StreamsChannel.broadcast_stream_to(
          [individual_category, :competition_tree], content: streams
        )
      end

      private def individual_category
        @individual_category ||= IndividualCategory.find(params.expect(:individual_category_id))
      end

      private def participation
        @participation ||= individual_category.participations.find(params.expect(:id))
      end

      private def streams
        helpers.safe_join([seeds_panel_stream, pools_container_stream, bracket_tree_stream].compact)
      end

      private def seeds_panel_stream
        helpers.turbo_stream.replace(
          "individual_seeds_#{individual_category.id}",
          IndividualSeedsComponent.new(category: individual_category)
        )
      end

      private def pools_container_stream
        helpers.turbo_stream.replace(
          "individual_pools_#{individual_category.id}",
          partial: "admin/individual_categories/pools",
          locals: {category: individual_category}
        )
      end

      private def bracket_tree_stream
        return if individual_category.bracket_fights.none?

        helpers.turbo_stream.replace(
          helpers.dom_id(individual_category, :competition_tree),
          CompetitionTreeComponent.new(category: individual_category, admin: true)
        )
      end
    end
  end
end

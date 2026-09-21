# frozen_string_literal: true

module Admin
  module IndividualCategories
    # What goes stale on this side when either freeze flag moves.
    #
    # One stream holds everything: the pool cards and the tree both subscribe
    # to [category, :competition_tree], and the seeds panel has no
    # subscription of its own — it rides theirs.
    #
    # Both flags send the same set, because both change all of it. A pools
    # freeze closes the draw; a bracket freeze closes it too (R5), since any
    # membership move clears the tree as a side effect — so the grips and move
    # selects have to go either way, and the seed controls are blocked by
    # either flag.
    module FreezeStreams
      extend ActiveSupport::Concern

      private def category
        @category ||= IndividualCategory.find(params.expect(:individual_category_id))
      end

      private def category_path = admin_individual_category_path(category)

      # Memoised: Admin::Freezing renders this twice — once to broadcast, once
      # for the acting admin's own response — and building it twice would both
      # double the render (every pool card, the unpooled panel, the seeds panel
      # and the whole tree) and open a window for the two to disagree, which is
      # exactly what the module promises cannot happen.
      private def streams
        @streams ||= {competition_tree: helpers.safe_join(
          [*pool_surface_streams, tree_actions_stream, tree_stream]
        )}
      end

      # Skipped for a pool-less category: app/admin/individual_category.rb
      # renders the Seeding and Pools panels only on pool_size > 1, so there is
      # no target on the page and every card would be rendered into the void.
      private def pool_surface_streams
        return [] unless category.pool_size.to_i > 1

        [pools_actions_stream, pools_container_stream, unpooled_panel_stream, seeds_panel_stream]
      end

      private def pools_actions_stream
        helpers.turbo_stream.replace(
          helpers.freeze_actions_dom_id(category, :pools),
          partial: "admin/individual_categories/pools_actions", locals: {category: category}
        )
      end

      private def pools_container_stream
        helpers.turbo_stream.replace(
          "individual_pools_#{category.id}",
          partial: "admin/individual_categories/pools", locals: {category: category}
        )
      end

      private def unpooled_panel_stream
        helpers.turbo_stream.replace(
          "individual_pool_unpooled_#{category.id}",
          IndividualPoolUnpooledComponent.new(category: category)
        )
      end

      private def seeds_panel_stream
        helpers.turbo_stream.replace(
          "individual_seeds_#{category.id}", IndividualSeedsComponent.new(category: category)
        )
      end

      private def tree_actions_stream
        helpers.turbo_stream.replace(
          helpers.freeze_actions_dom_id(category, :bracket),
          partial: "admin/individual_categories/tree_actions", locals: {category: category}
        )
      end

      private def tree_stream
        helpers.turbo_stream.replace(
          helpers.dom_id(category, :competition_tree),
          CompetitionTreeComponent.new(category: category, admin: true)
        )
      end
    end
  end
end

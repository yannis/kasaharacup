# frozen_string_literal: true

module Admin
  module TeamCategories
    # What goes stale on this side when a freeze flag moves, and on which
    # stream.
    #
    # Three streams rather than one, exactly as in
    # Admin::TeamCategories::SeedsController: the panel, the pool cards and the
    # bracket each subscribe separately here, so each gets only the content
    # that belongs to it — sending the whole set to each would apply the others
    # twice on a page holding more than one subscription.
    #
    # The two flags do NOT send the same set, unlike the individual side:
    #
    #   pools freeze   -> the pool surfaces, and the seeds panel (seeds drive
    #                     the draw). The bracket renders no differently.
    #   bracket freeze -> the bracket, the seeds panel, AND the pool surfaces:
    #                     R5 refuses a membership move while the bracket is
    #                     frozen, because the move would clear it, so the grips
    #                     have to go even though the pools are unfrozen.
    module FreezeStreams
      extend ActiveSupport::Concern

      private def category
        @category ||= TeamCategory.find(params.expect(:team_category_id))
      end

      private def category_path = admin_team_category_path(category)

      private def streams
        {
          team_pools: pool_surfaces_stream,
          team_seeds: seeds_panel_stream,
          encounter_tree: bracket_stream
        }.compact
      end

      # Skipped for a bracket-only category: app/admin/team_category.rb renders
      # the Pools panel only on pool_size > 1, so there is no target on the
      # page and every card would be rendered into the void.
      private def pool_surfaces_stream
        return if category.bracket_only?

        helpers.safe_join([
          helpers.turbo_stream.replace(
            helpers.freeze_actions_dom_id(category, :pools),
            partial: "admin/team_categories/pools_actions", locals: {team_category: category}
          ),
          helpers.turbo_stream.replace(
            "team_pools_#{category.id}",
            partial: "admin/team_categories/pools", locals: {team_category: category}
          ),
          helpers.turbo_stream.replace(
            "team_pool_unpooled_#{category.id}",
            TeamPoolUnpooledComponent.new(team_category: category)
          )
        ])
      end

      private def seeds_panel_stream
        helpers.turbo_stream.replace(
          "team_seeds_#{category.id}", TeamSeedsComponent.new(category: category)
        )
      end

      # Only when a bracket exists: the Bracket panel — chrome included — is
      # rendered only on bracket_encounters.any?, so there is nothing to
      # replace before the first draw.
      private def bracket_stream
        return unless category.bracket_encounters.exists?

        helpers.safe_join([
          helpers.turbo_stream.replace(
            helpers.freeze_actions_dom_id(category, :bracket),
            partial: "admin/team_categories/bracket_actions", locals: {team_category: category}
          ),
          helpers.turbo_stream.replace(
            helpers.dom_id(category, :encounter_tree),
            partial: "team_bracket_trees/team_bracket_tree", locals: {team_category: category}
          )
        ])
      end
    end
  end
end

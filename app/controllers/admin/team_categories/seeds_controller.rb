# frozen_string_literal: true

module Admin
  module TeamCategories
    # Seeds a team of a team category, reorders the seeds, or unseeds one. The
    # ordering and renumbering live in SeedOrderMove; :id is the team id, the
    # convention pool_memberships already uses.
    #
    # Twin of Admin::IndividualCategories::SeedsController, and the differences
    # are worth naming:
    #
    # The response carries more than the panel, as its sibling's does: a seeded
    # team wears its badge on the pool card and in the bracket, so both go
    # stale on a seed change and are replaced too.
    #
    # Where it really parts company is the broadcast. On the individual side
    # the panel, the pool cards and the tree all subscribe to one stream, so a
    # single broadcast reaches them. Here each surface has its own — the panel
    # because a bracket-only category (pool_size <= 1) renders no pool cards to
    # ride along with, the cards and the bracket because they already had one
    # before seeding existed. So this broadcasts three times, each with only
    # the stream that belongs to it: sending the whole set to each would apply
    # the other two twice on a page holding more than one subscription.
    #
    # No confirmation/422 flow, as on the individual side: nothing here discards
    # recorded work, so there is nothing to confirm.
    class SeedsController < Admin::BaseController
      def update
        apply(target_position)
      end

      def destroy
        apply(nil)
      end

      # A blank position unseeds, the way destroy does. Anything else has to be
      # a positive integer: params.expect rejects a non-scalar, and a
      # non-numeric string must not fall through to "abc".to_i's 0, which would
      # clamp to 1 and silently make that team the top seed.
      private def target_position
        return nil if params[:to_position].blank?

        position = Integer(params.expect(:to_position), exception: false)
        raise ActionController::BadRequest if position.nil? || position < 1

        position
      end

      # nil unseeds — SeedOrderMove reads a blank target that way.
      private def apply(to_position)
        result = SeedOrderMove.new(record: team, to_position: to_position).call
        broadcast unless result.status == :noop

        respond_to do |format|
          # The unseed control is a plain button_to, so the response has to be a
          # page for a browser that never ran Turbo.
          format.html { redirect_to admin_team_category_path(team_category) }
          format.turbo_stream do
            (result.status == :noop) ? head(:no_content) : render(turbo_stream: streams)
          end
        end
      end

      # Each surface subscribes to a stream of its own here, where the
      # individual side has the panel, the pool cards and the tree all sharing
      # one — so a seed change has to reach three rather than ride a single
      # broadcast. Sending the whole set to each would apply the other two
      # twice on a page holding more than one subscription.
      private def broadcast
        broadcast_to(:team_seeds, panel_stream)
        broadcast_to(:team_pools, pools_stream)
        broadcast_to(:encounter_tree, tree_stream)
      end

      private def broadcast_to(name, content)
        return if content.nil?

        Turbo::StreamsChannel.broadcast_stream_to([team_category, name], content: content)
      end

      private def team
        @team ||= team_category.teams.find(params.expect(:id))
      end

      # Memoised: broadcast and render both want the same set, and rendering it
      # twice would re-run the panel, every pool card and the whole bracket for
      # identical output.
      private def streams
        @streams ||= helpers.safe_join([panel_stream, pools_stream, tree_stream].compact)
      end

      private def panel_stream
        @panel_stream ||= helpers.turbo_stream.replace(
          "team_seeds_#{team_category.id}",
          TeamSeedsComponent.new(category: team_category)
        )
      end

      # A seeded team wears its badge on the pool card, so the cards go stale on
      # a seed change the same way the panel does.
      #
      # morph, not a plain replace: the cards embed an encounter editor per
      # pool encounter, and only a badge changed. A replace would collapse
      # every open <details> and discard an in-flight inline edit, here and on
      # every other admin page following the broadcast.
      #
      # Memoised including the "nothing to replace" answer, as tree_stream is:
      # broadcast and render both ask, and the guard costs a query.
      private def pools_stream
        return @pools_stream if defined?(@pools_stream)

        @pools_stream = if pool_cards?
          helpers.turbo_stream.replace(
            "team_pools_#{team_category.id}",
            method: :morph,
            partial: "admin/team_categories/pools",
            locals: {team_category: team_category}
          )
        end
      end

      # Both halves are needed, and bracket_only? has to come first.
      #
      # It is not merely the cheap half: app/admin/team_category.rb renders the
      # container on pool_size > 1, so a category switched back to 1 has NO
      # target on the page even while its teams still carry the pool_number the
      # last draw left them — team_pools alone would render every card and
      # broadcast them into the void. The second half then skips the pooled
      # category whose pools are not drawn yet, where the container is on the
      # page but holds no card a seed could go stale on.
      private def pool_cards?
        !team_category.bracket_only? && team_category.team_pools.any?
      end

      # Memoised including the "nothing to replace" answer: broadcast and
      # render both ask, and the guard is a query of its own.
      private def tree_stream
        return @tree_stream if defined?(@tree_stream)

        @tree_stream = if team_category.bracket_encounters.exists?
          helpers.turbo_stream.replace(
            helpers.dom_id(team_category, :encounter_tree),
            partial: "team_bracket_trees/team_bracket_tree",
            locals: {team_category: team_category}
          )
        end
      end
    end
  end
end

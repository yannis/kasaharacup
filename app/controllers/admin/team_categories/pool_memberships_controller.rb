# frozen_string_literal: true

module Admin
  module TeamCategories
    # Moves a team into another pool (drag-and-drop on the pool cards, or the
    # accessible "Move to" select). A team's pool membership is the resource;
    # the move itself lives in TeamPoolMove. When the move would discard real
    # work, the service returns :needs_confirmation and we answer 422 so the
    # client can confirm and retry with force=true.
    class PoolMembershipsController < Admin::BaseController
      def update
        team = team_category.teams.find(params.expect(:id))
        result = TeamPoolMove.new(team: team, to_pool_number: params[:to_pool_number], force: forced?).call

        case result.status
        when :needs_confirmation
          render json: {message: result.message}, status: :unprocessable_content
        when :noop
          head :no_content
        else
          broadcast(result)
          render turbo_stream: streams_for(result)
        end
      end

      private def forced?
        ActiveModel::Type::Boolean.new.cast(params[:force])
      end

      # Identical actions to the acting admin (immediate) and every other open
      # session (broadcast) — built once so the two can never drift.
      private def broadcast(result)
        Turbo::StreamsChannel.broadcast_stream_to([team_category, :team_pools], content: streams_for(result))
      end

      private def streams_for(result)
        tags = if result.created_pool
          # A brand-new pool: replace the whole container (re-rendering every
          # card) rather than appending one. The acting admin is subscribed to
          # the same stream we broadcast to, so an append would be applied twice
          # on their own page; a container replace is idempotent. It also
          # refreshes — or drops — the source pool card as a side effect.
          [pools_container_stream, unpooled_panel_stream]
        else
          # A real source pool is replaced (or removed when emptied); an unpooled
          # source (a late registrant joining) has no card to update.
          [destination_stream(result), source_stream(result), unpooled_panel_stream]
        end
        tags << bracket_tree_stream if result.bracket_cleared
        helpers.safe_join(tags.compact)
      end

      # An existing pool's card is replaced in place. Un-pooling (no destination
      # pool) touches no destination card — only the unpooled panel and source.
      private def destination_stream(result)
        return if result.to_pool.nil?

        pool_card_stream(result.to_pool)
      end

      private def source_stream(result)
        return if result.from_pool.nil?

        if result.emptied_pools.include?(result.from_pool)
          helpers.turbo_stream.remove(pool_dom_id(result.from_pool))
        else
          pool_card_stream(result.from_pool)
        end
      end

      private def pools_container_stream
        helpers.turbo_stream.replace(
          "team_pools_#{team_category.id}",
          partial: "admin/team_categories/pools",
          locals: {team_category: team_category}
        )
      end

      private def pool_card_stream(pool_number)
        helpers.turbo_stream.replace(
          pool_dom_id(pool_number),
          partial: "admin/team_categories/pool_card",
          locals: {team_category: team_category, pool_number: pool_number}
        )
      end

      private def unpooled_panel_stream
        helpers.turbo_stream.replace(
          "team_pool_unpooled_#{team_category.id}",
          partial: "admin/team_categories/pool_unpooled",
          locals: {team_category: team_category}
        )
      end

      private def bracket_tree_stream
        helpers.turbo_stream.replace(
          helpers.dom_id(team_category, :encounter_tree),
          partial: "team_bracket_trees/team_bracket_tree",
          locals: {team_category: team_category}
        )
      end

      private def pool_dom_id(pool_number)
        "team_pool_#{team_category.id}_#{pool_number}"
      end
    end
  end
end

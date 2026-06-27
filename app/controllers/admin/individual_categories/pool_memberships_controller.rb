# frozen_string_literal: true

module Admin
  module IndividualCategories
    # Moves a participation into another pool (drag-and-drop on the pool cards,
    # or the accessible "Move to" select). The membership change lives in
    # PoolMembershipMove. When the move would discard real work, the service
    # returns :needs_confirmation and we answer 422 so the client can confirm
    # and retry with force=true. Individual analog of
    # Admin::TeamCategories::PoolMembershipsController.
    class PoolMembershipsController < Admin::BaseController
      def update
        participation = individual_category.participations.find(params.expect(:id))
        result = PoolMembershipMove.new(
          participation: participation, to_pool_number: params[:to_pool_number], force: forced?
        ).call

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

      private def individual_category
        @individual_category ||= IndividualCategory.find(params.expect(:individual_category_id))
      end

      private def forced?
        ActiveModel::Type::Boolean.new.cast(params[:force])
      end

      private def broadcast(result)
        Turbo::StreamsChannel.broadcast_stream_to(
          [individual_category, :competition_tree], content: streams_for(result)
        )
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
          [destination_stream(result), source_stream(result), unpooled_panel_stream]
        end
        tags << bracket_tree_stream if result.bracket_cleared
        helpers.safe_join(tags.compact)
      end

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
          "individual_pools_#{individual_category.id}",
          partial: "admin/individual_categories/pools",
          locals: {category: individual_category}
        )
      end

      private def pool_card_stream(pool_number)
        helpers.turbo_stream.replace(
          pool_dom_id(pool_number),
          PoolComponent.new(category: individual_category, pool_number: pool_number, admin: true)
        )
      end

      private def unpooled_panel_stream
        helpers.turbo_stream.replace(
          "individual_pool_unpooled_#{individual_category.id}",
          IndividualPoolUnpooledComponent.new(category: individual_category)
        )
      end

      private def bracket_tree_stream
        helpers.turbo_stream.replace(
          helpers.dom_id(individual_category, :competition_tree),
          CompetitionTreeComponent.new(category: individual_category, admin: true)
        )
      end

      private def pool_dom_id(pool_number)
        helpers.pool_dom_id(individual_category, pool_number)
      end
    end
  end
end

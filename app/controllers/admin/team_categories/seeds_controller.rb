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
    # The response carries the panel and nothing else. Its individual sibling
    # also replaces the pool cards and the competition tree because those wear
    # seed badges; the team pool cards and bracket do not, so there is nothing
    # else on the page a seed change can make stale.
    #
    # It broadcasts on the panel's OWN stream rather than riding the pool
    # cards': a bracket-only category (pool_size <= 1) renders no pool cards at
    # all, so there would be no subscriber to carry the panel's replace. The
    # panel subscribes to that stream itself.
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

      private def broadcast
        Turbo::StreamsChannel.broadcast_stream_to([team_category, :team_seeds], content: streams)
      end

      private def team_category
        @team_category ||= TeamCategory.find(params.expect(:team_category_id))
      end

      private def team
        @team ||= team_category.teams.find(params.expect(:id))
      end

      # Memoised: broadcast and render both want the same set.
      private def streams
        @streams ||= helpers.turbo_stream.replace(
          "team_seeds_#{team_category.id}",
          TeamSeedsComponent.new(category: team_category)
        )
      end
    end
  end
end

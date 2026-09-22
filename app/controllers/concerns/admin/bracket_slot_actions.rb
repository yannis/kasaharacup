# frozen_string_literal: true

module Admin
  # The update/destroy body both bracket kinds share. The includer supplies
  # #category, #tree_stream and #broadcast_stream_name; everything else — the
  # freeze guard, the parameter shapes, the refusal statuses and the paired
  # re-render — is identical, and has to be, because "may this entry go here?"
  # is one question with one answer.
  #
  # There is no HTML branch. Every write arrives from bracket_slot_controller.js
  # by fetch, whether the admin dragged a grip or chose from a select, so there
  # is one request shape and one response shape. That is what lets the server
  # own the confirm decision, which in turn is what removes the encounter
  # panel's per-option verdicts.
  module BracketSlotActions
    extend ActiveSupport::Concern

    included do
      before_action :refuse_when_bracket_frozen
    end

    def update
      changed = move.place(
        target: params.expect(:id),
        source: slot_params[:source_slot],
        entry_key: slot_params[:entry],
        expected_entry: slot_params[:expected_entry],
        expected_source_entry: slot_params[:expected_source_entry],
        force: forced?
      )
      respond_with_bracket(changed)
    rescue BracketSlotMove::NeedsConfirmation, BracketSlotMove::InvalidMove => e
      refuse(e)
    end

    def destroy
      changed = move.remove(
        target: params.expect(:id),
        expected_entry: slot_params[:expected_entry],
        force: forced?
      )
      respond_with_bracket(changed)
    rescue BracketSlotMove::NeedsConfirmation, BracketSlotMove::InvalidMove => e
      refuse(e)
    end

    private def move = BracketSlotMove.new(category)

    private def refuse_when_bracket_frozen = guard_frozen_bracket!(category)

    # Identical actions to the acting admin (immediately) and to every other
    # open session (by broadcast), built ONCE and handed to both so the two can
    # never differ — the PoolMembershipsController idiom.
    #
    # This broadcast is load-bearing rather than a belt beside the model's
    # braces: a move that rewrites labels alone saves no competitor-id change,
    # so neither Encounter#broadcast_bracket_tree nor
    # Fight#broadcast_competition_tree fires for it.
    private def respond_with_bracket(changed)
      return head :no_content unless changed

      streams = helpers.safe_join([tree_stream, waiting_stream])
      Turbo::StreamsChannel.broadcast_stream_to(broadcast_stream_name, content: streams)
      render turbo_stream: streams
    end

    private def waiting_stream
      helpers.turbo_stream.replace(
        BracketWaitingComponent.dom_id_for(category),
        BracketWaitingComponent.new(category: category),
        method: :morph
      )
    end

    # Both refusals answer 422; only NeedsConfirmation is worth re-offering, so
    # the flag tells the client whether to prompt or just report. content_type
    # is forced for the same reason Admin::FreezeGuard forces it: the request
    # asked for a Turbo Stream, and the json renderer would leave that label on
    # a JSON body.
    private def refuse(error)
      render json: {message: error.message, confirm: error.is_a?(BracketSlotMove::NeedsConfirmation)},
        status: :unprocessable_content, content_type: "application/json"
    end

    # permit (not params[...]) so a non-scalar value is dropped rather than
    # reaching #split in the service, where `source_slot[]=1` would raise
    # NoMethodError and 500.
    private def slot_params
      @slot_params ||= params.permit(:source_slot, :entry, :expected_entry, :expected_source_entry)
    end

    private def forced?
      ActiveModel::Type::Boolean.new.cast(params[:force])
    end
  end
end

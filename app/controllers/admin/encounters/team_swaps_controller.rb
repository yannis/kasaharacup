# frozen_string_literal: true

module Admin
  module Encounters
    # Swaps a bracket-only round-1 slot's occupant with another round-1 team —
    # the admin's draw-correction tool (see EncounterTeamSwap for the rules).
    # A swap that would discard a fighter order answers 422 with confirm: true
    # so the drag client can confirm and retry with force=true.
    class TeamSwapsController < Admin::BaseController
      def create
        team = team_category.teams.find(params.expect(:team_id))
        EncounterTeamSwap.new(encounter).swap(
          params.expect(:slot).to_i, team,
          expected_team_id: hints[:expected_team_id],
          expected_encounter_id: hints[:expected_encounter_id],
          force: forced?
        )

        respond_to do |format|
          # The panel's select form posts with data-turbo-frame="_top": it wants
          # a real navigation so the flash renders above the updated bracket.
          format.html { redirect_to admin_team_category_path(team_category), notice: t(".notice") }
          # The drag client renders this itself, so the acting admin sees the new
          # draw without waiting on a job. Every OTHER open session is covered by
          # Encounter#broadcast_invalidated_matchup, which both assign_team_to_slot
          # calls reach — NOT by #broadcast_bracket_tree, whose own condition reads
          # false here (the slot write is no longer the last save, so its
          # saved_changes never reach commit). So unlike PoolMembershipsController
          # we broadcast nothing by hand.
          format.turbo_stream { render turbo_stream: tree_stream }
        end
      rescue EncounterTeamSwap::NeedsConfirmation, EncounterTeamSwap::InvalidSwap => e
        refuse(e)
      end

      # Both refusals answer 422 to the drag client; only NeedsConfirmation is
      # worth re-offering, so the flag tells the client whether to prompt or
      # just report.
      private def refuse(error)
        if request.format.turbo_stream?
          render json: {message: error.message, confirm: error.is_a?(EncounterTeamSwap::NeedsConfirmation)},
            status: :unprocessable_content
        else
          redirect_to admin_team_category_path(team_category), alert: flash_refusal(error)
        end
      end

      # The drag client turns NeedsConfirmation into a confirm dialog and
      # retries; the panel form cannot — it has already navigated away, so the
      # question would arrive as a flash nobody can answer. Swap the question
      # for what to do about it. Reopening the panel re-renders the form with
      # the verdict this refusal proves it was missing, and confirming there
      # goes through.
      private def flash_refusal(error)
        return error.message unless error.is_a?(EncounterTeamSwap::NeedsConfirmation)

        error.message.sub(
          EncounterTeamSwap::CONFIRM_QUESTION,
          "Reopen the encounter and swap again to confirm."
        )
      end

      # permit (not params[...]) so a non-scalar value is dropped rather than
      # reaching #to_i in the service, where `expected_team_id[]=1` would raise
      # NoMethodError and 500.
      private def hints
        @hints ||= params.permit(:expected_team_id, :expected_encounter_id)
      end

      private def forced?
        ActiveModel::Type::Boolean.new.cast(params[:force])
      end

      private def tree_stream
        helpers.turbo_stream.replace(
          helpers.dom_id(team_category, :encounter_tree),
          EncounterTreeComponent.new(team_category: team_category, admin: true),
          method: :morph
        )
      end
    end
  end
end

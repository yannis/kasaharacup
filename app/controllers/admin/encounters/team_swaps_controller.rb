# frozen_string_literal: true

module Admin
  module Encounters
    # Swaps a bracket-only round-1 slot's occupant with another round-1 team —
    # the admin's draw-correction tool (see EncounterTeamSwap for the rules).
    class TeamSwapsController < Admin::BaseController
      def create
        team = team_category.teams.find(params.expect(:team_id))
        EncounterTeamSwap.new(encounter).swap(
          params.expect(:slot).to_i, team, expected_team_id: params[:expected_team_id]
        )

        respond_to do |format|
          # The panel's select form posts with data-turbo="false": it wants a
          # real redirect so the flash renders above the updated bracket.
          format.html { redirect_to admin_team_category_path(team_category), notice: t(".notice") }
          # The drag client renders this itself, so the acting admin sees the new
          # draw without waiting on a job. Every OTHER open session is covered by
          # Encounter#broadcast_bracket_tree, which both assign_team_to_slot calls
          # already fire — so unlike PoolMembershipsController we broadcast
          # nothing by hand here.
          format.turbo_stream { render turbo_stream: tree_stream }
        end
      rescue EncounterTeamSwap::InvalidSwap => e
        if request.format.turbo_stream?
          render json: {message: e.message}, status: :unprocessable_content
        else
          redirect_to admin_team_category_path(team_category), alert: e.message
        end
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

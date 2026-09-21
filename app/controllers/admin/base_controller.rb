# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    include Admin::FreezeGuard

    before_action :authenticate_admin_user!

    private def respond_with_tree(category, notice: nil)
      respond_to do |format|
        format.html { redirect_to admin_individual_category_path(category), notice: notice }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            helpers.dom_id(category, :competition_tree),
            CompetitionTreeComponent.new(category: category, admin: true),
            method: :morph
          )
        end
      end
    end

    private def respond_with_pool(category, pool_number, notice: nil)
      respond_to do |format|
        format.html { redirect_to admin_individual_category_path(category), notice: notice }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            helpers.pool_dom_id(category, pool_number),
            PoolComponent.new(category: category, pool_number: pool_number, admin: true),
            method: :morph
          )
        end
      end
    end

    private def respond_with_encounter(encounter, notice: nil)
      respond_to do |format|
        format.html do
          redirect_to admin_team_category_encounter_path(encounter.team_category, encounter),
            notice: notice
        end
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              helpers.dom_id(encounter),
              EncounterComponent.new(encounter: encounter, admin: true, alert: flash[:alert]),
              method: :morph
            ),
            # The bracket swap form sits OUTSIDE the panel this replaces and
            # bakes its per-option confirmation verdicts in at render time, so
            # a lineup entered here has to redraw it or the next swap submits a
            # verdict taken before the lineup existed. A no-op everywhere the
            # form is not on the page (pool encounters, the tree) — Turbo drops
            # a stream whose target is missing, and the partial itself renders
            # nothing but its wrapper unless the encounter is swappable.
            turbo_stream.replace(
              helpers.dom_id(encounter, :swap_team),
              partial: "admin/encounters/swap_team",
              locals: {encounter: encounter}
            )
          ]
        end
      end
    end

    # Shared finders for the encounter-scoped controllers (daihyōsens, team
    # fights, team-fight points), which are all nested under an encounter.
    private def team_category
      @team_category ||= TeamCategory.find(params.expect(:team_category_id))
    end

    private def encounter
      @encounter ||= team_category.encounters.find(params.expect(:encounter_id))
    end
  end
end

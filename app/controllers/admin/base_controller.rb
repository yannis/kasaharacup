# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
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
          render turbo_stream: turbo_stream.replace(
            helpers.dom_id(encounter),
            EncounterComponent.new(encounter: encounter, admin: true),
            method: :morph
          )
        end
      end
    end
  end
end

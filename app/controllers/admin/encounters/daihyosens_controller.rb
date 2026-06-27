# frozen_string_literal: true

module Admin
  module Encounters
    # Edits the daihyōsen representatives. Each id is resolved THROUGH that team's
    # roster (TeamFight enforces no such membership), so an off-team pick is
    # rejected. Locked once the bout has points (changing a scored rep would
    # orphan the result), mirroring EncounterLineup.
    class DaihyosensController < Admin::BaseController
      def update
        return head :unprocessable_content if daihyosen.fight_points.exists?

        daihyosen.update!(rep_params)
        respond_with_encounter(encounter)
      rescue ActiveRecord::RecordNotFound
        head :unprocessable_content
      end

      private def rep_params
        attrs = {}
        attrs[:kenshi_1_id] = member_id(encounter.resolved_team_1, params[:kenshi_1_id]) if params.key?(:kenshi_1_id)
        attrs[:kenshi_2_id] = member_id(encounter.resolved_team_2, params[:kenshi_2_id]) if params.key?(:kenshi_2_id)
        attrs
      end

      # nil for a blank pick; raises RecordNotFound (-> 422) for an off-team id
      # or an unresolved slot (no team yet), rather than 500ing on nil.kenshis.
      private def member_id(team, raw)
        return nil if raw.blank?
        raise ActiveRecord::RecordNotFound unless team

        team.kenshis.find(raw).id
      end

      private def daihyosen
        @daihyosen ||= encounter.team_fights.find_by!(daihyosen: true)
      end
    end
  end
end

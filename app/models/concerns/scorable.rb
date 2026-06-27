# frozen_string_literal: true

# Shared point-scoring slice for records that are scored by FightPoints
# (Fight, TeamFight). Includers implement four hooks:
#   scoring_fighter(slot)  -> the fighter object on side 1/2 (id is read off it)
#   forfeit                -> the fighter that wins by default, or nil
#   tie_outcome(s1, s2)    -> {winner_id:, draw:} when both sides have equal points
#   refresh_after_points   -> refresh downstream state when the outcome is unchanged
module Scorable
  extend ActiveSupport::Concern

  included do
    has_many :fight_points, -> { order(:position) }, as: :scorable, dependent: :destroy
  end

  def points_for(slot)
    side = (slot == 1) ? "fighter_1" : "fighter_2"
    fight_points.select { |point| point.fighter_side == side }
  end

  def first_scoring_point
    fight_points.reject { |point| point.kind == "hansoku" }.min_by(&:position)
  end

  # Derives the outcome from points: a forfeit short-circuits to the present
  # side; otherwise the side with more non-hansoku points wins; an equal score
  # defers to the includer's tie_outcome. Returns true when the persisted
  # outcome actually changed, false when it was already up to date.
  def recompute_outcome_from_points!
    outcome =
      if (winner_by_default = forfeit)
        {winner_id: winner_by_default.id, draw: false}
      else
        scored_1 = scoring_points_count(1)
        scored_2 = scoring_points_count(2)
        if scored_1 > scored_2
          {winner_id: scoring_fighter(1)&.id, draw: false}
        elsif scored_2 > scored_1
          {winner_id: scoring_fighter(2)&.id, draw: false}
        else
          tie_outcome(scored_1, scored_2)
        end
      end

    return false if winner_id == outcome[:winner_id] && draw == outcome[:draw]

    update!(outcome)
    true
  end

  # Outcome recomputation reads straight from the DB: it runs in write paths
  # (point create/destroy, slot invalidation) where a cached fight_points set may
  # be stale, so accuracy beats reusing a loaded association here. Read-side
  # callers that count points for display use the in-memory points_for instead.
  private def scoring_points_count(slot)
    side = (slot == 1) ? "fighter_1" : "fighter_2"
    fight_points.where(fighter_side: side).where.not(kind: "hansoku").count
  end
end

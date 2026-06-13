# frozen_string_literal: true

class FightPoint < ApplicationRecord
  CODES = {
    "men" => "M", "kote" => "K", "do" => "D",
    "tsuki" => "T", "ippon" => "I", "hansoku" => "△"
  }.freeze

  belongs_to :scorable, polymorphic: true, touch: true

  enum :fighter_side, {fighter_1: "fighter_1", fighter_2: "fighter_2"}
  enum :kind, {
    men: "men", kote: "kote", do: "do",
    tsuki: "tsuki", ippon: "ippon", hansoku: "hansoku"
  }

  validates :position, presence: true, uniqueness: {scope: [:scorable_type, :scorable_id]}
  validate :non_hansoku_point_limit_per_side, on: :create

  before_validation :assign_position, on: :create

  after_commit :recompute_scorable_outcome, on: [:create, :destroy]

  scope :ordered, -> { order(:position) }

  def code
    CODES.fetch(kind)
  end

  # When the owning record is being destroyed (its points cascade with it), the
  # post-commit callback fires on the already-frozen record — skip it. Otherwise
  # re-derive the outcome from points; when it did NOT change, ask the record to
  # refresh its own downstream state (pool standings for a Fight, the encounter
  # for a TeamFight) so a second viewer still sees a fresh, committed render.
  private def recompute_scorable_outcome
    return if scorable.destroyed?

    outcome_changed = scorable.recompute_outcome_from_points!
    scorable.refresh_after_points unless outcome_changed
  end

  private def assign_position
    return if position.present?
    return if scorable_id.blank?

    self.position = (self.class.where(scorable_type: scorable_type, scorable_id: scorable_id)
      .maximum(:position) || 0) + 1
  end

  private def non_hansoku_point_limit_per_side
    return if hansoku?
    return if scorable_id.blank? || fighter_side.blank?

    existing = self.class
      .where(scorable_type: scorable_type, scorable_id: scorable_id, fighter_side: fighter_side)
      .where.not(kind: "hansoku")
    return if existing.count < 2

    errors.add(:base, "Fighter already has 2 non-hansoku points")
  end
end

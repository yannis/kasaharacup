# frozen_string_literal: true

class FightPoint < ApplicationRecord
  CODES = {
    "men" => "M",
    "kote" => "K",
    "do" => "D",
    "tsuki" => "T",
    "ippon" => "I",
    "hansoku" => "△"
  }.freeze

  belongs_to :fight, touch: true

  enum :fighter_side, {fighter_1: "fighter_1", fighter_2: "fighter_2"}
  enum :kind, {
    men: "men", kote: "kote", do: "do",
    tsuki: "tsuki", ippon: "ippon", hansoku: "hansoku"
  }

  validates :position, presence: true, uniqueness: {scope: :fight_id}
  validate :non_hansoku_point_limit_per_side, on: :create

  before_validation :assign_position, on: :create

  after_commit :recompute_fight_outcome, on: [:create, :destroy]

  scope :ordered, -> { order(:position) }

  def code
    CODES.fetch(kind)
  end

  # Pool match outcomes are computed from the points, so any point change
  # re-derives the owning fight's winner/draw.
  private def recompute_fight_outcome
    fight.recompute_outcome_from_points!
  end

  private def assign_position
    return if position.present?
    return if fight_id.blank?

    self.position = (self.class.where(fight_id: fight_id).maximum(:position) || 0) + 1
  end

  private def non_hansoku_point_limit_per_side
    return if hansoku?
    return if fight_id.blank? || fighter_side.blank?

    existing = self.class.where(fight_id: fight_id, fighter_side: fighter_side).where.not(kind: "hansoku")
    return if existing.count < 2

    errors.add(:base, "Fighter already has 2 non-hansoku points")
  end
end

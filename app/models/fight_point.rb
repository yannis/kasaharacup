# frozen_string_literal: true

class FightPoint < ApplicationRecord
  CODES = {
    "men" => "M", "kote" => "K", "do" => "D",
    "tsuki" => "T", "ippon" => "I", "hansoku" => "△",
    "hansoku_ippon" => "H"
  }.freeze

  # The scoring buttons: the H is never entered by hand, every second hansoku
  # a fighter receives awards one to the opponent (#1345).
  ENTERABLE_CODES = CODES.except("hansoku_ippon").freeze

  belongs_to :scorable, polymorphic: true, touch: true

  enum :fighter_side, {fighter_1: "fighter_1", fighter_2: "fighter_2"}
  enum :kind, {
    men: "men", kote: "kote", do: "do",
    tsuki: "tsuki", ippon: "ippon", hansoku: "hansoku",
    hansoku_ippon: "hansoku_ippon"
  }

  validates :position, presence: true, uniqueness: {scope: [:scorable_type, :scorable_id]}
  validate :non_hansoku_point_limit_per_side, on: :create
  validate :hansoku_ippon_earned, on: :create, if: :hansoku_ippon?

  before_validation :assign_position, on: :create

  # Inside the hansoku's own transaction, so a hansoku whose H cannot be
  # awarded (the opponent already has two points) rolls back with it. A
  # cascade from the scorable destroys the H itself, so it skips the sync.
  after_create :sync_hansoku_ippons, if: :hansoku?
  after_destroy :sync_hansoku_ippons, if: :hansoku?, unless: :destroyed_by_association

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
  #
  # A hansoku never scores, so it cannot change the outcome — skip the
  # recompute, which would otherwise read a hansoku-only bout as 0-0 and wipe
  # an admin-marked hikiwake (#1343).
  private def recompute_scorable_outcome
    return if scorable.destroyed?

    outcome_changed = !hansoku? && scorable.recompute_outcome_from_points!
    scorable.refresh_after_points unless outcome_changed
  end

  # Keeps one H on the opponent's side per pair of hansoku on this one: the
  # second (fourth) hansoku adds it, removing one of a pair takes the last H
  # back. The H scores, so its own commit callback recomputes the outcome.
  private def sync_hansoku_ippons
    earned = siblings.where(fighter_side: fighter_side, kind: "hansoku").count / 2
    awarded = siblings.where(fighter_side: opponent_side, kind: "hansoku_ippon")

    if awarded.count < earned
      self.class.create!(scorable: scorable, fighter_side: opponent_side, kind: "hansoku_ippon")
    elsif awarded.count > earned
      awarded.order(:position).last.destroy!
    end
  end

  private def hansoku_ippon_earned
    return if scorable_id.blank? || fighter_side.blank?

    earned = siblings.where(fighter_side: opponent_side, kind: "hansoku").count / 2
    return if siblings.where(fighter_side: fighter_side, kind: "hansoku_ippon").count < earned

    errors.add(:base, "An H point needs two hansoku on the opponent")
  end

  private def siblings
    self.class.where(scorable_type: scorable_type, scorable_id: scorable_id)
  end

  private def opponent_side
    fighter_1? ? "fighter_2" : "fighter_1"
  end

  private def assign_position
    return if position.present?
    return if scorable_id.blank?

    self.position = (siblings.maximum(:position) || 0) + 1
  end

  private def non_hansoku_point_limit_per_side
    return if hansoku?
    return if scorable_id.blank? || fighter_side.blank?

    existing = siblings.where(fighter_side: fighter_side).where.not(kind: "hansoku")
    return if existing.count < 2

    errors.add(:base, "Fighter already has 2 non-hansoku points")
  end
end

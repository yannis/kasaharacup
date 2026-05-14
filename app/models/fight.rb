# frozen_string_literal: true

class Fight < ApplicationRecord
  include ActionView::RecordIdentifier

  belongs_to :individual_category
  belongs_to :winner, polymorphic: true, foreign_type: "fighter_type", optional: true
  belongs_to :parent_fight_1, class_name: "Fight", optional: true
  belongs_to :parent_fight_2, class_name: "Fight", optional: true
  belongs_to :fighter_1, polymorphic: true, foreign_type: "fighter_type", optional: true
  belongs_to :fighter_2, polymorphic: true, foreign_type: "fighter_type", optional: true

  has_many :fight_points, -> { order(:position) }, dependent: :destroy

  validates :number, presence: true
  validates :round, presence: true
  validates :position, presence: true
  validates :number, uniqueness: {scope: :individual_category_id}
  validates :position, uniqueness: {scope: [:individual_category_id, :round]}

  validate :fighters_participate_in_category
  validate :winner_is_a_fighter

  before_validation :restore_fighter_type

  after_update :cascade_winner_clear_to_descendants, if: :saved_change_to_winner_id?
  after_update_commit :broadcast_competition_tree, if: :saved_change_to_winner_id?

  scope :bracket_order, -> { order(:round, :position) }

  PARENT_ASSOCIATIONS = [:parent_fight_1, :parent_fight_2].freeze

  # Wires each fight's parent_fight_1 / parent_fight_2 to the already-loaded
  # fight rows so callers can walk the tree without re-querying.
  def self.preload_parents(fights)
    by_id = fights.index_by(&:id)
    fights.each do |fight|
      PARENT_ASSOCIATIONS.each do |name|
        association = fight.association(name)
        association.target = by_id[fight.public_send(:"#{name}_id")]
        association.loaded!
      end
    end
  end

  def fighters
    [resolved_fighter_1, resolved_fighter_2].compact
  end

  def participating_kenshis
    [fighter_1, fighter_2, resolved_fighter_1, resolved_fighter_2, winner, bye_fighter].compact
  end

  def points_for(slot)
    side = (slot == 1) ? "fighter_1" : "fighter_2"
    fight_points.select { |point| point.fighter_side == side }
  end

  def first_scoring_point
    fight_points.reject { |point| point.kind == "hansoku" }.min_by(&:position)
  end

  def resolved_fighter_1
    fighter_1 || parent_fight_1&.winner_or_bye
  end

  def resolved_fighter_2
    fighter_2 || parent_fight_2&.winner_or_bye
  end

  def winner_or_bye
    winner.presence || bye_fighter
  end

  def bye?
    bye_slot.present?
  end

  def bye_slot
    return 1 if slot_present?(1) && !slot_present?(2) && parent_fight_2.blank?
    return 2 if slot_present?(2) && !slot_present?(1) && parent_fight_1.blank?

    nil
  end

  def bye_fighter
    return unless bye_slot

    public_send(:"resolved_fighter_#{bye_slot}")
  end

  private def slot_present?(slot)
    public_send(:"fighter_#{slot}").present? ||
      public_send(:"fighter_#{slot}_pool_number").present?
  end

  def winner_name
    winner&.full_name
  end

  private def broadcast_competition_tree
    broadcast_replace_later_to(
      [individual_category, :competition_tree],
      target: dom_id(individual_category, :competition_tree),
      partial: "competition_trees/competition_tree",
      locals: {category: individual_category},
      attributes: {method: :morph}
    )
  end

  private def fighters_participate_in_category
    validate_fighter_participates(:fighter_1, fighter_1)
    validate_fighter_participates(:fighter_2, fighter_2)
  end

  private def validate_fighter_participates(attribute, fighter)
    return if fighter.blank?
    return if fighter_participates?(fighter)

    errors.add(attribute, "must participate in the category")
  end

  private def fighter_participates?(fighter)
    if fighter.participations.loaded?
      fighter.participations.any? { |participation| participation.category == individual_category }
    else
      fighter.participations.exists?(category: individual_category)
    end
  end

  private def winner_is_a_fighter
    return if winner.blank? || fighters.include?(winner)

    errors.add(:winner, "must be one of the fighters")
  end

  # When a winner changes, any descendant whose recorded winner is no longer
  # one of its resolved fighters is orphaned. Clear those winners; each cleared
  # fight re-fires this callback on its own descendants, so the effect
  # cascades down the bracket.
  private def cascade_winner_clear_to_descendants
    fights_with_self_as_parent.find_each do |child|
      next if child.winner_id.nil?
      next if child.fighters.any?(child.winner)

      child.update!(winner: nil)
    end
  end

  private def fights_with_self_as_parent
    self.class.where(individual_category_id: individual_category_id)
      .where("parent_fight_1_id = :id OR parent_fight_2_id = :id", id: id)
  end

  private def restore_fighter_type
    return if fighter_type.present?
    return unless fighter_1_id || fighter_2_id || winner_id

    self.fighter_type = "Kenshi"
  end
end

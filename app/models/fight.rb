# frozen_string_literal: true

class Fight < ApplicationRecord
  include ActionView::RecordIdentifier
  include Scorable
  include BracketSlots

  SLOT_PREFIX = "fighter"

  belongs_to :individual_category
  belongs_to :winner, polymorphic: true, foreign_type: "fighter_type", optional: true
  belongs_to :parent_fight_1, class_name: "Fight", optional: true
  belongs_to :parent_fight_2, class_name: "Fight", optional: true
  belongs_to :fighter_1, polymorphic: true, foreign_type: "fighter_type", optional: true
  belongs_to :fighter_2, polymorphic: true, foreign_type: "fighter_type", optional: true

  validates :number, presence: true
  validates :round, presence: true, if: -> { pool_number.blank? }
  validates :position, presence: true, if: -> { pool_number.blank? }
  validates :number,
    uniqueness: {scope: :individual_category_id, conditions: -> { where(pool_number: nil) }},
    if: -> { pool_number.blank? }
  validates :number,
    uniqueness: {scope: [:individual_category_id, :pool_number]},
    if: -> { pool_number.present? }
  validates :position,
    uniqueness: {scope: [:individual_category_id, :round]},
    if: -> { position.present? }

  validate :fighters_participate_in_category
  validate :winner_is_a_fighter
  validate :draw_constraints
  validate :kettei_sen_constraints

  before_validation :restore_fighter_type

  after_update :cascade_winner_clear_to_descendants, if: :saved_change_to_winner_id?
  after_update_commit :broadcast_competition_tree,
    if: -> { saved_change_to_winner_id? && pool_number.blank? }

  after_commit :recompute_pool_ranks,
    on: [:create, :destroy],
    if: -> { pool_number.present? }
  after_commit :recompute_pool_ranks_on_change,
    on: :update,
    if: -> { pool_number.present? && (saved_change_to_winner_id? || saved_change_to_draw?) }
  after_commit :broadcast_pool_panel,
    on: [:create, :destroy],
    if: -> { pool_number.present? }
  after_commit :broadcast_pool_panel_on_change,
    on: :update,
    if: -> { pool_number.present? && (saved_change_to_winner_id? || saved_change_to_draw?) }

  scope :bracket_order, -> { order(:round, :position) }

  # See Encounter.with_slot_competitors / .with_slot_move_context.
  scope :with_slot_competitors, -> { includes(:fighter_1, :fighter_2) }
  scope :with_slot_move_context, -> { with_slot_competitors.includes(:fight_points) }

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

  # A tree fight, as opposed to one played inside a pool. The distinction the
  # freeze guards turn on: Admin::FightPointsController serves both, and the
  # pool phase goes on being recorded while the bracket is locked.
  def bracket? = pool_number.nil?

  def fighters
    [resolved_fighter_1, resolved_fighter_2].compact
  end

  def participating_kenshis
    [fighter_1, fighter_2, resolved_fighter_1, resolved_fighter_2, winner, bye_fighter].compact
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

  # No result recorded: no winner, not a draw, no scored points. The bar a draw
  # correction has to clear before it may rewrite a slot, and the bar a pool
  # rebuild has to clear before it may discard a fight.
  #
  # Named #unscored? to match Encounter, because BracketSlots asks both models
  # the same question and BracketSlotMove refuses on the answer. Encounter keeps
  # #unscored? and #pristine? apart — its #pristine? additionally excludes a
  # hand-entered lineup, which is a prompt there and not a refusal — but a fight
  # has no lineup, so here the two really are one method.
  def unscored?
    winner_id.nil? && !draw && fight_points.none?
  end

  alias_method :pristine?, :unscored?

  # --- Scorable hooks (preserve current individual-fight behavior) ---
  def scoring_fighter(slot)
    public_send(:"resolved_fighter_#{slot}")
  end

  def forfeit
    nil # individual fights have no default/forfeit concept
  end

  def tie_outcome(scored_1, scored_2)
    if pool_number.present? && (scored_1.positive? || scored_2.positive?)
      {winner_id: nil, draw: true}
    else
      {winner_id: nil, draw: false}
    end
  end

  # refresh_after_points is also a Scorable hook (defined below alongside
  # refresh_pool_standings).

  # Recomputes/persists the pool standings and broadcasts the refreshed panel.
  # Driven from FightPoint's after_commit so the refresh always lands
  # post-commit: an after_touch refresh used to enqueue the broadcast inside the
  # point's own transaction, letting the job render before the write committed
  # and push stale data to a second viewer. No-op for bracket fights, which have
  # no pool panel.
  def refresh_pool_standings
    return if pool_number.blank?

    recompute_pool_ranks
    broadcast_pool_panel
  end

  # Refresh downstream state when a point did not change the outcome. For an
  # individual fight this is the pool-standings panel (a no-op for bracket fights).
  def refresh_after_points
    refresh_pool_standings
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

  # Re-derives the pool's standings and persists each fighter's distinct rank
  # into pool_rank, so the merged Rank column (and the bracket it seeds) always
  # reflects the latest results. Admins can still override pool_rank in place;
  # the override holds until the next result change recomputes it.
  private def recompute_pool_ranks
    pool_participations = individual_category.participations.where(pool_number: pool_number).to_a
    pool_fights = individual_category.pool_fights.where(pool_number: pool_number)
      .includes(:fight_points).to_a
    PoolStandings.persist_ranks!(participations: pool_participations, fights: pool_fights)
  end

  private alias_method :recompute_pool_ranks_on_change, :recompute_pool_ranks

  private def broadcast_pool_panel
    broadcast_replace_later_to(
      [individual_category, :competition_tree],
      target: "pool_#{pool_number}_#{dom_id(individual_category)}",
      partial: "admin/pool_fights/pool",
      locals: {category: individual_category, pool_number: pool_number, admin: true},
      attributes: {method: :morph}
    )
  end

  private alias_method :broadcast_pool_panel_on_change, :broadcast_pool_panel

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

  # Public because BracketSlotMove walks a unit's blast radius through it, the
  # way it does on Encounter.
  def children
    self.class.where(individual_category_id: individual_category_id)
      .where("parent_fight_1_id = :id OR parent_fight_2_id = :id", id: id)
  end

  private def fights_with_self_as_parent = children

  # The Fight half of BracketSlots' contract. See Encounter for the
  # counterparts, which do considerably more.

  # A slot's occupant changed, so whatever was recorded against the old matchup
  # is stale. Defence in depth rather than a live path: BracketSlotMove refuses
  # a move over a scored fight, so in practice there is nothing here to discard.
  # Encounter's equivalent is load-bearing because a bye's round-2 child is
  # rewritten by propagation, on a path with no unscored? gate of its own.
  private def invalidate_slot_matchup
    fight_points.destroy_all
    update!(winner: nil, draw: false) if winner_id.present? || draw
  end

  # A no-op, and deliberately so: a child fight reads its fighters lazily
  # through parent_fight_N&.winner_or_bye and IndividualCategoryBracketBuilder
  # seeds nothing into it, so there is no copy of a bye's occupant to keep
  # current. Encounter forward-propagates instead, and pays for it there.
  private def refresh_child_slot_from_bye = nil

  # See Encounter#seeds_child_slots?. False here: #resolved_fighter_N reads
  # parent_fight_N&.winner_or_bye on demand, so nothing is stored to go stale
  # and nothing can collide.
  def seeds_child_slots? = false

  # fighter_type is ONE column shared by fighter_1, fighter_2 and winner, so it
  # is set whenever a competitor lands and left alone when one leaves —
  # #restore_fighter_type puts it back for any row that still holds an id.
  private def slot_extra_attributes(entry)
    entry.competitor ? {fighter_type: entry.competitor.class.name} : {}
  end

  private def restore_fighter_type
    return if fighter_type.present?
    return unless fighter_1_id || fighter_2_id || winner_id

    self.fighter_type = "Kenshi"
  end

  private def draw_constraints
    return unless draw

    errors.add(:draw, "only allowed on pool fights") if pool_number.blank?
    errors.add(:draw, "cannot coexist with a winner") if winner_id.present?
  end

  private def kettei_sen_constraints
    return unless tiebreaker

    errors.add(:tiebreaker, "only allowed on pool fights") if pool_number.blank?
    errors.add(:fighter_1, "is required for a kettei-sen") if fighter_1_id.blank?
    errors.add(:fighter_2, "is required for a kettei-sen") if fighter_2_id.blank?
    if fighter_1_id.present? && fighter_1_id == fighter_2_id
      errors.add(:fighter_2, "must differ from fighter 1")
    end
  end
end

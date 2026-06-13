# frozen_string_literal: true

class Encounter < ApplicationRecord
  belongs_to :team_category
  belongs_to :team_1, class_name: "Team", optional: true
  belongs_to :team_2, class_name: "Team", optional: true
  belongs_to :parent_encounter_1, class_name: "Encounter", optional: true
  belongs_to :parent_encounter_2, class_name: "Encounter", optional: true
  belongs_to :winner, class_name: "Team", optional: true
  has_many :team_fights, -> { order(:position) }, dependent: :destroy

  validate :teams_differ
  validate :teams_in_category
  validates :team_1, :team_2, presence: true, if: -> { pool_number.present? }

  scope :bracket_order, -> { order(:round, :position) }

  after_update :propagate_winner_to_children, if: :saved_change_to_winner_id?
  after_update :cascade_winner_clear_to_descendants, if: :saved_change_to_winner_id?
  after_update :propagate_bye_to_children, if: :bye_occupant_changed?
  # Winner changes AND slot-occupant changes (admin swaps, bye re-seeding)
  # redraw the tree; pool encounters never do.
  after_update_commit :broadcast_bracket_tree, if: -> {
    pool_number.blank? &&
      (saved_change_to_winner_id? || saved_change_to_team_1_id? || saved_change_to_team_2_id?)
  }

  delegate :team_size, to: :team_category

  PARENT_ASSOCIATIONS = [:parent_encounter_1, :parent_encounter_2].freeze

  def self.preload_parents(encounters)
    by_id = encounters.index_by(&:id)
    encounters.each do |encounter|
      PARENT_ASSOCIATIONS.each do |name|
        association = encounter.association(name)
        association.target = by_id[encounter.public_send(:"#{name}_id")]
        association.loaded!
      end
    end
  end

  def resolved_team_1
    team_1 || parent_encounter_1&.winner_or_bye
  end

  def resolved_team_2
    team_2 || parent_encounter_2&.winner_or_bye
  end

  def winner_or_bye
    winner.presence || bye_team
  end

  def team_display_name(slot)
    public_send(:"resolved_team_#{slot}")&.name || "To be decided"
  end

  def teams
    [resolved_team_1, resolved_team_2].compact
  end

  def participating_teams
    [team_1, team_2, resolved_team_1, resolved_team_2, winner, bye_team].compact.uniq
  end

  def bye?
    bye_slot.present?
  end

  def bye_slot
    return 1 if slot_present?(1) && !slot_present?(2) && parent_encounter_2.blank?
    return 2 if slot_present?(2) && !slot_present?(1) && parent_encounter_1.blank?

    nil
  end

  def bye_team
    return unless bye_slot

    public_send(:"resolved_team_#{bye_slot}")
  end

  def result
    EncounterResult.new(self)
  end

  # Persist the derived winning team; no-op when already current. Called
  # post-commit (from TeamFight), so its own write never lands mid-transaction.
  def recompute_winner!
    derived = result.winner
    update!(winner: derived) unless winner_id == derived&.id
    recompute_pool_standings! if pool_number.present?
  end

  # The single path for setting a bracket slot's team. First fill (nil -> team)
  # just writes the column. Re-resolution (a different team, or nil) first
  # invalidates the previous occupant's sub-state on that side, then writes the
  # column and re-derives this encounter's winner. Both the winner-propagation
  # callback and the builder's first-round re-resolve go through here, so stale
  # state can never survive an advancement change.
  def assign_team_to_slot(slot, team)
    column = :"team_#{slot}_id"
    return if public_send(column) == team&.id

    previous_id = public_send(column)
    update!(column => team&.id)

    if previous_id.present? && team&.id != previous_id
      invalidate_slot(slot)
      recompute_winner!
    end
  end

  def recompute_pool_standings!
    pool_teams = team_category.teams.where(pool_number: pool_number).to_a
    pool_encounters = team_category.encounters.where(pool_number: pool_number)
      .includes(team_fights: :fight_points).to_a
    TeamPoolStandings.persist_ranks!(teams: pool_teams, encounters: pool_encounters)
  end

  def children
    self.class.where(team_category_id: team_category_id)
      .where("parent_encounter_1_id = :id OR parent_encounter_2_id = :id", id: id)
  end

  # Wipe the previous occupant's data on side `slot`: kenshi, that side's
  # fight_points (they are keyed by fighter_side, NOT by kenshi, so they would
  # otherwise be counted for the new team), and the now-stale per-bout outcome.
  private def invalidate_slot(slot)
    side = (slot == 1) ? "fighter_1" : "fighter_2"
    team_fights.each do |fight|
      fight.fight_points.where(fighter_side: side).destroy_all
      fight.update!("kenshi_#{slot}_id": nil)
      fight.recompute_outcome_from_points!
    end
    update!("lineup_#{slot}_set": false)
  end

  private def broadcast_bracket_tree
    broadcast_replace_later_to(
      [team_category, :encounter_tree],
      target: ActionView::RecordIdentifier.dom_id(team_category, :encounter_tree),
      partial: "team_bracket_trees/team_bracket_tree",
      locals: {team_category: team_category},
      attributes: {method: :morph}
    )
  end

  private def propagate_winner_to_children
    children.find_each do |child|
      slot = (child.parent_encounter_1_id == id) ? 1 : 2
      child.assign_team_to_slot(slot, winner)
    end
  end

  # A bye advances via bye_team, never winner_id, so the winner-propagation
  # callback can't keep round 2 current when a bye's occupant changes (admin
  # slot swap, or a pooled re-resolve). Mirror it for byes.
  private def bye_occupant_changed?
    (saved_change_to_team_1_id? || saved_change_to_team_2_id?) && winner_id.nil? && bye?
  end

  private def propagate_bye_to_children
    children.find_each do |child|
      slot = (child.parent_encounter_1_id == id) ? 1 : 2
      child.assign_team_to_slot(slot, bye_team)
    end
  end

  private def cascade_winner_clear_to_descendants
    children.find_each do |child|
      next if child.winner_id.nil?
      next if [child.team_1_id, child.team_2_id].include?(child.winner_id)

      child.update!(winner: nil)
    end
  end

  private def slot_present?(slot)
    public_send(:"team_#{slot}").present? ||
      public_send(:"team_#{slot}_pool_number").present?
  end

  private def teams_differ
    errors.add(:team_2, "must differ from team 1") if team_1_id && team_1_id == team_2_id
  end

  private def teams_in_category
    [team_1, team_2].compact.each do |team|
      next if team.team_category_id == team_category_id

      errors.add(:base, "#{team.name} is not in this category")
    end
  end
end

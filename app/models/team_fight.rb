# frozen_string_literal: true

class TeamFight < ApplicationRecord
  include Scorable

  belongs_to :encounter, touch: true
  belongs_to :kenshi_1, class_name: "Kenshi", optional: true
  belongs_to :kenshi_2, class_name: "Kenshi", optional: true
  belongs_to :winner, class_name: "Kenshi", optional: true

  after_update_commit :refresh_encounter, if: -> { saved_change_to_winner_id? || saved_change_to_draw? }

  # Points credited to a side for the encounter ippon count: a forfeit gives the
  # present side 2 (rule: a default is a loss, opponent gets 2 points).
  def individual_points(slot)
    return 2 if forfeit && forfeit == public_send(:"kenshi_#{slot}")
    return 0 if forfeit

    scoring_points_count(slot)
  end

  # Called by EncounterLineup once BOTH lineups are in. Resolves only the
  # structural outcome — a forfeit win, or clearing a stale forfeit winner when a
  # re-entered lineup fills the empty side. It never marks an unfought both-present
  # fight as a 0-0 hikiwake; that draw is the admin's explicit call during scoring.
  def resolve_lineup!
    if forfeit
      update!(winner_id: forfeit.id, draw: false) unless winner_id == forfeit.id && !draw
    elsif fight_points.empty? && (winner_id.present? || draw)
      update!(winner_id: nil, draw: false)
    end
  end

  # --- Scorable hooks ---
  def scoring_fighter(slot)
    public_send(:"kenshi_#{slot}")
  end

  # Both slots empty — a position neither short team filled. Counts for no one
  # and must not block encounter completeness.
  def void?
    kenshi_1_id.nil? && kenshi_2_id.nil?
  end

  # Exactly one side empty => that side forfeits; the present kenshi wins.
  def forfeit
    return nil if kenshi_1_id.present? == kenshi_2_id.present?

    kenshi_1 || kenshi_2
  end

  def tie_outcome(_scored_1, _scored_2)
    if daihyosen?
      {winner_id: nil, draw: false} # ippon-shobu: undecided until someone scores
    else
      {winner_id: nil, draw: true}  # hikiwake (0-0 or 1-1)
    end
  end

  def refresh_after_points
    refresh_encounter
  end

  private def refresh_encounter
    encounter.recompute_winner!
    broadcast_replace_later_to(
      [encounter, :panel],
      target: ActionView::RecordIdentifier.dom_id(encounter),
      partial: "admin/encounters/panel",
      locals: {encounter: encounter, admin: true},
      attributes: {method: :morph}
    )
    return if encounter.pool_number.blank?

    broadcast_replace_later_to(
      [encounter.team_category, :team_pools],
      target: "team_pool_#{encounter.team_category_id}_#{encounter.pool_number}",
      partial: "admin/team_categories/team_pool",
      locals: {team_category: encounter.team_category, pool_number: encounter.pool_number},
      attributes: {method: :morph}
    )
  end
end

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

    # Display/standings read: count off the (preloaded) association in memory so
    # rolling an encounter up to ippons reuses loaded points instead of a COUNT
    # per bout. points_for is a plain in-memory select on fight_points.
    points_for(slot).count { |point| point.kind != "hansoku" }
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

  # A bout the admin may mark hikiwake by hand: a confirmed, both-present,
  # unscored, undecided regular bout. The 0-0 both-present case is the only one
  # not already settled by points or forfeit resolution. Gating on the lineup
  # flags matters because auto-seeded fighters persist before confirmation, and
  # a pre-confirmation draw would be wiped by resolve_lineup! on confirmation.
  def hikiwake_eligible?
    !daihyosen? && !void? && forfeit.nil? && fight_points.none? &&
      winner_id.nil? && encounter.lineups_confirmed?
  end

  # Exactly one side empty => that side forfeits; the present kenshi wins.
  #
  # Gated on BOTH lineups being confirmed, exactly as #hikiwake_eligible? is.
  # A half-filled matchup is not a walkover: fighters persist as soon as a
  # panel is opened, so a bout can hold one side because only one parent has
  # been decided yet, or because a slot re-resolution just emptied the other.
  # Reading that as a forfeit let recompute_winner! record a clean-sweep win
  # nobody fought, which advanced up the tree and locked the slot (#1310).
  # The genuine forfeit is unaffected: EncounterLineup resolves forfeits only
  # after it has set both flags, and EncounterLineupSeeder confirms a side even
  # when the team has NO members to seed — otherwise a walkover against an empty
  # roster would sit here forever, unresolvable (that side's panel select has no
  # options, so it can never fire the change event the lineup form submits on).
  def forfeit
    return nil unless encounter.lineups_confirmed?
    return nil if kenshi_1_id.present? == kenshi_2_id.present?

    kenshi_1 || kenshi_2
  end

  def tie_outcome(scored_1, scored_2)
    if daihyosen?
      {winner_id: nil, draw: false} # ippon-shobu: undecided until someone scores
    elsif void? || (scored_1.zero? && scored_2.zero?)
      # A void bout (an unfilled position) is no contest; a 0-0 with no points is
      # unscored. Either way leave the bout pending — a genuine 0-0 hikiwake is
      # the admin's explicit call (Admin::TeamFightsController), never an
      # automatic consequence of deleting the last recorded point.
      {winner_id: nil, draw: false}
    else
      {winner_id: nil, draw: true}  # hikiwake (e.g. 1-1)
    end
  end

  def refresh_after_points
    refresh_encounter
  end

  private def refresh_encounter
    encounter.recompute_winner!
    encounter.broadcast_panel
    return if encounter.pool_number.blank?

    broadcast_replace_later_to(
      [encounter.team_category, :team_pools],
      target: "team_pool_standings_#{encounter.team_category_id}_#{encounter.pool_number}",
      partial: "admin/team_categories/pool_standings",
      locals: {team_category: encounter.team_category, pool_number: encounter.pool_number, admin: true},
      attributes: {method: :morph}
    )
    # The <summary> is pool-view content, so it rides the pool stream (which the
    # pool card subscribes to) rather than the encounter's own panel stream —
    # keeps the standalone encounter page from receiving an irrelevant morph.
    broadcast_replace_later_to(
      [encounter.team_category, :team_pools],
      target: ActionView::RecordIdentifier.dom_id(encounter, :summary),
      partial: "admin/encounters/summary",
      locals: {encounter: encounter},
      attributes: {method: :morph}
    )
  end
end

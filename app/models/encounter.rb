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

  after_commit :broadcast_invalidated_matchup, on: :update, if: -> { @matchup_invalidated }
  # The flag lives on the instance, so a rolled-back invalidation (a swap whose
  # second #assign_team_to_slot raises) would otherwise leave it set and repaint
  # on the next unrelated save of that same object.
  after_rollback :clear_matchup_invalidated

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

  # No RESULT recorded: no winner, no scored bout and no bout the admin marked
  # hikiwake. The bar a draw-correction swap has to clear.
  #
  # #draw is checked as well as the points because a 0-0 hikiwake leaves NO
  # other trace: TeamFight#hikiwake_eligible? requires an unscored bout, and an
  # all-hikiwake encounter derives no winner, so reading points alone reported a
  # fully decided drawn encounter as untouched and let a swap destroy it.
  #
  # Deliberately blind to the lineup flags. EncounterLineupSeeder confirms BOTH
  # lineups the moment an admin opens a panel, so gating on them made the swap
  # tool withdraw itself a second after anyone merely looked at an encounter. A
  # seeded lineup is not a result: #assign_team_to_slot -> #invalidate_matchup
  # drops the stale bouts and both lineup flags on every swap, and
  # EncounterTeamSwap confirms before discarding the rest.
  def unscored?
    winner_id.nil? &&
      # any? (not exists?) so a preloaded team_fights: :fight_points association is
      # read in memory instead of firing one EXISTS query per bout.
      team_fights.none? { |fight| fight.fight_points.any? || fight.draw? }
  end

  # Both sides' fighter orders are in. The single bar for reading a matchup as
  # settled — forfeit resolution, hikiwake eligibility and encounter
  # completeness all hinge on it, and they have to agree or #1310 comes back.
  #
  # NOT the negation of #pristine?'s lineup half below, which asks whether
  # NEITHER side has been entered.
  def lineups_confirmed?
    lineup_1_set? && lineup_2_set?
  end

  # No work recorded AT ALL — #unscored? plus untouched lineups. The stricter
  # bar, used where re-resolving a slot would silently discard an order the
  # admin entered by hand and cannot recover: TeamCategoryBracketBuilder's
  # non-force update, and TeamPoolMove's confirmation prompt.
  def pristine?
    unscored? && !lineup_1_set? && !lineup_2_set?
  end

  # Persist the derived winning team; no-op when already current. Called
  # post-commit (from TeamFight), so its own write never lands mid-transaction.
  #
  # Wrapped in with_lock: under live multi-tablet scoring two bouts of the same
  # encounter commit concurrently and each fires this derive+write. Without a row
  # lock both read their own snapshot and the later commit can persist a winner
  # derived from a stale read of the other bout. The lock serializes the
  # read-derive-write so the second recompute sees the first's committed outcome.
  def recompute_winner!
    with_lock do
      # Drop any loaded team_fights so the result reads the just-written bout
      # outcomes from the DB. A scored bout updates its own row, but the encounter
      # instance reaching this write path may carry a stale cached collection (the
      # same DB-over-cache rule Scorable applies to point recomputation).
      team_fights.reset
      res = result
      derived = res.winner
      update!(winner: derived) unless winner_id == derived&.id

      if pool_number.present?
        # Standings count only complete encounters, so re-rank the pool only when
        # this encounter is complete now or just stopped being complete (e.g. a
        # point was deleted). Scoring an early bout that leaves it incomplete is
        # the common case and needs no re-rank.
        now_complete = res.complete?
        recompute_pool_standings! if now_complete || completed?
        update_column(:completed, now_complete) if completed? != now_complete # rubocop:disable Rails/SkipsModelValidations
      else
        DaihyosenProposal.new(self).ensure!
      end
    end
  end

  # The single path for setting a bracket slot's team. First fill (nil -> team)
  # just writes the column. Re-resolution (a different team, or nil) writes the
  # column, discards the now-stale matchup, then re-derives this encounter's
  # winner. Both the winner-propagation callback and the builder's first-round
  # re-resolve go through here, so stale state can never survive an advancement
  # change.
  #
  # Wrapped in its own transaction so the three writes land together: a failure
  # between them (a lock timeout, FK contention under concurrent scoring) would
  # otherwise leave the encounter holding the NEW team with the OLD bouts — the
  # #1310 state, reached by a partial failure instead of by design. It also
  # gives #invalidate_matchup's flag a commit to ride on when the caller has no
  # transaction of its own.
  def assign_team_to_slot(slot, team)
    column = :"team_#{slot}_id"
    return if public_send(column) == team&.id

    previous_id = public_send(column)
    transaction do
      update!(column => team&.id)
      next if previous_id.blank?

      invalidate_matchup
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

  # A slot's occupant changed, so the MATCHUP changed and the whole bout set is
  # stale — not just the side being rewritten. The outgoing team's fighters and
  # points obviously go (points are keyed by fighter_side, not by kenshi, so
  # they would otherwise be credited to the incoming team); the opponent's go
  # too, because that order was entered to face a team that is no longer there.
  #
  # Emptying only the rewritten side left every bout with one fighter and an
  # empty seat, which TeamFight#forfeit read as a walkover: recompute_winner!
  # then handed the untouched side a clean-sweep win nobody fought, and that
  # phantom result advanced up the tree and made the slot unswappable for good
  # (#1310).
  #
  # This reaches every RE-resolution caller — winner propagation, bye
  # propagation and the builder's first-round re-resolve — but by construction
  # it cannot reach a first fill (nil -> team), where a panel opened before both
  # parents are decided seeds one side and leaves the other empty. So #1310 is
  # closed in two places, and both are load-bearing: this one removes the stale
  # matchup, and TeamFight#forfeit's own lineup gate stops a half-filled one
  # being read as a walkover for as long as it legitimately exists.
  private def invalidate_matchup
    # Raised BEFORE the writes, not after: the after_commit guard is read at
    # commit time, so a flag set after the last save never reaches it and the
    # repaint below silently never fires.
    @matchup_invalidated = true
    log_discarded_matchup
    team_fights.destroy_all
    update!(lineup_1_set: false, lineup_2_set: false)
  end

  # Correcting an earlier round can reach a descendant that was already fought
  # and scored, on a path that — unlike EncounterTeamSwap — has no unscored?
  # guard and no confirmation prompt. Discarding those points is unavoidable
  # (they are keyed by fighter_side, not by kenshi, so keeping the opponent's
  # half would credit them to the incoming team), but it should not be silent:
  # leave a trace for when someone asks where a scoresheet went.
  private def log_discarded_matchup
    fights = team_fights.to_a
    # Read the points in memory where the caller preloaded them — the bracket
    # builder loads team_fights: :fight_points for every encounter it
    # re-resolves, and pays this on each of them for a line that is almost never
    # written. One subquery COUNT otherwise. Same trade-off #unscored? documents.
    points = if fights.all? { |fight| fight.fight_points.loaded? }
      fights.sum { |fight| fight.fight_points.size }
    else
      FightPoint.where(scorable: fights).count
    end
    return if points.zero?

    bouts = fights.size
    Rails.logger.warn(
      "Encounter #{id}: matchup invalidated, discarding " \
      "#{bouts} #{"bout".pluralize(bouts)} and " \
      "#{points} recorded #{"fight point".pluralize(points)}"
    )
  end

  # Repaint every screen showing this matchup — neither existing broadcast
  # survives an invalidation. The bouts are DESTROYED, and TeamFight repaints the
  # panel only from an after_update_commit, so an open editor keeps rendering
  # bouts whose ids are gone (scoring one then 404s in TeamFightPointsController).
  # The tree is exposed on the swap path for a different reason: the slot write is
  # no longer the last save, so its saved_changes never reach commit and
  # broadcast_bracket_tree's own condition reads false. Measured before this fix:
  # a swap enqueued 0 panel and 0 tree broadcasts, a correction 0 panel.
  #
  # Re-sending a tree another record already broadcast is an idempotent morph, so
  # this deliberately does not try to detect that.
  private def broadcast_invalidated_matchup
    clear_matchup_invalidated
    broadcast_panel
    broadcast_bracket_tree if pool_number.blank?
  end

  private def clear_matchup_invalidated
    @matchup_invalidated = false
  end

  # Shared with TeamFight, which repaints the same panel after scoring.
  def broadcast_panel
    broadcast_replace_later_to(
      [self, :panel],
      target: ActionView::RecordIdentifier.dom_id(self),
      partial: "admin/encounters/panel",
      locals: {encounter: self, admin: true},
      attributes: {method: :morph}
    )
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

  # Winner/bye changes propagate synchronously into child slots, each of which
  # re-fires these callbacks on its own children — a write cascade bounded by
  # tree height ONLY if the parent graph is acyclic. The bracket builder always
  # produces a DAG, but nothing in the schema enforces it, so a data anomaly
  # (a parent_encounter pointing at a descendant) would recurse forever. This
  # guard tracks the encounters currently propagating on this thread and skips
  # re-entering one already in the chain, breaking any cycle.
  PROPAGATION_GUARD_KEY = :encounter_propagation_visited

  private def with_propagation_guard
    visited = (Thread.current[PROPAGATION_GUARD_KEY] ||= Set.new)
    return if visited.include?(id)

    visited.add(id)
    begin
      yield
    ensure
      visited.delete(id)
    end
  end

  private def propagate_winner_to_children
    with_propagation_guard do
      children.find_each do |child|
        slot = (child.parent_encounter_1_id == id) ? 1 : 2
        child.assign_team_to_slot(slot, winner)
      end
    end
  end

  # A bye advances via bye_team, never winner_id, so the winner-propagation
  # callback can't keep round 2 current when a bye's occupant changes (admin
  # slot swap, or a pooled re-resolve). Mirror it for byes.
  private def bye_occupant_changed?
    (saved_change_to_team_1_id? || saved_change_to_team_2_id?) && winner_id.nil? && bye?
  end

  private def propagate_bye_to_children
    with_propagation_guard do
      children.find_each do |child|
        slot = (child.parent_encounter_1_id == id) ? 1 : 2
        child.assign_team_to_slot(slot, bye_team)
      end
    end
  end

  private def cascade_winner_clear_to_descendants
    with_propagation_guard do
      children.find_each do |child|
        next if child.winner_id.nil?
        next if [child.team_1_id, child.team_2_id].include?(child.winner_id)

        child.update!(winner: nil)
      end
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

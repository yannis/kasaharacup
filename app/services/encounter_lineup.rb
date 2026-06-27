# frozen_string_literal: true

# Assigns one team's ordered members to its side of every bout in an encounter,
# creating the team_size TeamFight rows on first use. Positions past the supplied
# list keep a nil kenshi on that side (a forfeit). Re-assigning a side overwrites
# only that side's kenshi at each position.
class EncounterLineup
  class InvalidLineup < StandardError; end

  def initialize(encounter)
    @encounter = encounter
    @team_size = encounter.team_size
  end

  # Confirm a side's lineup: write the fighters AND mark the side set, which is
  # what lets the tie/daihyōsen prompt and forfeit resolution kick in.
  def assign(team, kenshi_ids)
    write_side(team, kenshi_ids, confirm: true)
  end

  # Pre-fill a side's order without confirming it: the fighters land in their
  # bouts (so they can be reordered or scored) but lineup_#{slot}_set stays
  # false, so an unfought encounter doesn't read as a complete (tied) one. The
  # admin confirms later by editing, dragging, or scoring.
  def seed(team, kenshi_ids)
    write_side(team, kenshi_ids, confirm: false)
  end

  private def write_side(team, kenshi_ids, confirm:)
    # Index i maps to position i+1; a nil/blank entry is a forfeit at THAT
    # position, so keep it (don't compact) — compacting would slide every later
    # fighter up a slot and push the gap to the end.
    kenshi_ids = kenshi_ids.map { |id| id.presence&.to_i }
    slot = slot_for(team)
    validate!(team, kenshi_ids)

    @encounter.transaction do
      (1..@team_size).each do |position|
        fight = @encounter.team_fights.find_or_create_by!(position: position)
        current_kenshi_id = fight.public_send("kenshi_#{slot}_id")
        new_kenshi_id = kenshi_ids[position - 1]
        next if new_kenshi_id == current_kenshi_id

        # Reordering or replacing a fighter who already fought a scored bout
        # RESETS that bout — its points and recorded outcome belonged to the old
        # matchup, so they're cleared. delete_all (not destroy_all) drops the
        # points WITHOUT firing FightPoint's recompute callback, which would
        # otherwise re-mark the now-empty both-present bout as a 0-0 hikiwake; we
        # want it fully unresolved, ready to re-score. Filling an empty side
        # (current is nil) is a late lineup entry, not a replacement, so it keeps
        # the bout's existing points (e.g. an opponent's forfeit point stands).
        if current_kenshi_id.present? && fight.fight_points.exists?
          fight.fight_points.delete_all
          fight.update!("kenshi_#{slot}_id": new_kenshi_id, winner_id: nil, draw: false)
        else
          fight.update!("kenshi_#{slot}_id": new_kenshi_id)
        end
      end
      next unless confirm

      @encounter.update!("lineup_#{slot}_set": true)
      resolve_forfeits if @encounter.lineup_1_set? && @encounter.lineup_2_set?
    end

    # Post-commit: recompute_winner! is documented as never landing its write
    # mid-transaction, so re-evaluate the daihyōsen need after the commit.
    @encounter.recompute_winner! if confirm && @encounter.lineup_1_set? && @encounter.lineup_2_set?
  end

  private def resolve_forfeits
    @encounter.team_fights.reset
    @encounter.team_fights.each(&:resolve_lineup!)
  end

  private def slot_for(team)
    return 1 if team.id == @encounter.team_1_id
    return 2 if team.id == @encounter.team_2_id

    raise InvalidLineup, "team is not part of this encounter"
  end

  private def validate!(team, kenshi_ids)
    raise InvalidLineup, "too many members" if kenshi_ids.size > @team_size

    # Blank slots (nil) are forfeits, not fighters: exclude them from the
    # duplicate and membership checks so several gaps don't read as duplicates.
    present = kenshi_ids.compact
    raise InvalidLineup, "duplicate members" if present.uniq.size != present.size

    on_team = team.kenshis.where(id: present).pluck(:id)
    raise InvalidLineup, "member not on team" if (present - on_team).any?
  end
end

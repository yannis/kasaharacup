# frozen_string_literal: true

# Suggests a starting lineup order for one side of an encounter, so a fresh
# encounter's dropdowns open pre-filled instead of blank. The suggestion is the
# order the team used in its most recent OTHER encounter; failing that (the
# team has not fought yet), its roster order. Teams keep a stable fighter order
# across the tournament, so last time's order is almost always the right guess.
#
# This is advisory only — it never writes anything. The admin confirms it by
# editing any slot, which submits the shown lineup through EncounterLineup.
class EncounterLineupSuggestion
  def initialize(encounter)
    @encounter = encounter
    @team_size = encounter.team_size
  end

  # An ordered list of kenshi ids (nil where a position was/should be a forfeit)
  # for the resolved team on `slot`, capped at team_size. [] if no team yet.
  def for_slot(slot)
    team = @encounter.public_send(:"resolved_team_#{slot}")
    return [] unless team

    (previous_order(team) || roster_order(team)).first(@team_size)
  end

  private def previous_order(team)
    encounter = candidate_encounters(team).order(updated_at: :desc, id: :desc).first
    return unless encounter

    side = (encounter.team_1_id == team.id) ? 1 : 2
    encounter.team_fights.where(daihyosen: false).order(:position)
      .pluck(:"kenshi_#{side}_id")
  end

  # Encounters (other than this one) where the team fought a side whose lineup
  # was actually entered — a set lineup is what carries a meaningful order.
  private def candidate_encounters(team)
    @encounter.team_category.encounters
      .where.not(id: @encounter.id)
      .where(
        "(team_1_id = :t AND lineup_1_set = TRUE) OR (team_2_id = :t AND lineup_2_set = TRUE)",
        t: team.id
      )
  end

  private def roster_order(team)
    team.kenshis.pluck(:id)
  end
end

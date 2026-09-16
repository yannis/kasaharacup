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
    encounter = last_encounter_of(team)
    return unless encounter

    side = (encounter.team_1_id == team.id) ? 1 : 2
    encounter.team_fights.reject(&:daihyosen?).sort_by(&:position)
      .map { |fight| fight.public_send(:"kenshi_#{side}_id") }
  end

  # The team's most recent encounter other than this one where the side it sat
  # on had its lineup actually entered — a set lineup is what carries a
  # meaningful order. Picked out of the category's lineup-bearing encounters,
  # which are already in that order and loaded once for the whole page.
  private def last_encounter_of(team)
    @encounter.team_category.lineup_set_encounters.find do |candidate|
      next false if candidate.id == @encounter.id

      (candidate.team_1_id == team.id && candidate.lineup_1_set?) ||
        (candidate.team_2_id == team.id && candidate.lineup_2_set?)
    end
  end

  private def roster_order(team)
    team.kenshis.sort_by(&:id).map(&:id)
  end
end

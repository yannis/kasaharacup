# frozen_string_literal: true

# Fills a fresh encounter's bouts with each side's suggested order (see
# EncounterLineupSuggestion) so the dropdowns open populated and the fighters
# are immediately draggable. The order is persisted but NOT confirmed — a side
# already set, already populated, or with no valid suggestion is left untouched.
# Best-effort: a suggestion gone stale (a member left the team) just skips that
# side rather than failing the whole seed.
class EncounterLineupSeeder
  def initialize(encounter)
    @encounter = encounter
    @suggestion = EncounterLineupSuggestion.new(encounter)
  end

  def call
    [1, 2].each { |slot| seed(slot) }
    @encounter
  end

  private def seed(slot)
    return if @encounter.public_send(:"lineup_#{slot}_set?")
    return if populated?(slot)

    team = @encounter.public_send(:"resolved_team_#{slot}")
    return unless team

    ids = @suggestion.for_slot(slot)
    return if ids.compact.empty?

    EncounterLineup.new(@encounter).seed(team, ids)
  rescue EncounterLineup::InvalidLineup
    nil # leave this side for manual entry
  end

  private def populated?(slot)
    @encounter.team_fights.where(daihyosen: false)
      .where.not("kenshi_#{slot}_id" => nil).exists?
  end
end

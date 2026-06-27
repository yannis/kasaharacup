# frozen_string_literal: true

# Fills a fresh encounter's bouts with each side's suggested order (see
# EncounterLineupSuggestion) and CONFIRMS it (lineup_#{slot}_set), so an opened
# encounter is immediately usable — fighters are draggable, bouts can be marked
# hikiwake, and the encounter can complete — without the admin re-entering an
# already-correct lineup. A side already set, already populated, or with no valid
# suggestion is left untouched. Confirming is safe because the tie/daihyōsen
# logic keys off EncounterResult#complete? (which still needs fought bouts), so
# this never produces a premature tie on an unfought encounter.
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

    EncounterLineup.new(@encounter).assign(team, ids)
  rescue EncounterLineup::InvalidLineup
    nil # leave this side for manual entry
  rescue ActiveRecord::RecordNotUnique
    # The lineup Stimulus controller auto-POSTs a seed on connect, so two tablets
    # (or a double-load) can open a fresh encounter at once: both pass the
    # populated? guard (no bouts exist yet) and race find_or_create_by!(position:)
    # on the (encounter_id, position) unique index. The loser's transaction rolls
    # back here; the winner has seeded the side, so treat it as already-seeded
    # rather than surfacing a 500 (mirrors DaihyosenProposal's race guard).
    @encounter.team_fights.reset
  end

  private def populated?(slot)
    column = (slot == 1) ? :kenshi_1_id : :kenshi_2_id
    @encounter.team_fights.where(daihyosen: false).where.not(column => nil).exists?
  end
end

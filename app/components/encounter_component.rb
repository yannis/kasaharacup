# frozen_string_literal: true

class EncounterComponent < ViewComponent::Base
  include ActionView::RecordIdentifier

  def initialize(encounter:, admin: false, alert: nil, auto_seed: false)
    @encounter = encounter
    @admin = admin
    @alert = alert
    @auto_seed = auto_seed
    @result = encounter.result
  end

  attr_reader :encounter, :admin, :result, :alert

  # data-* for the encounter container: the lineup controller, plus the seed
  # endpoint it POSTs to on open when this is a freshly-opened editor with an
  # unset, unpopulated side that has a suggestion to lay down.
  def container_data
    data = {controller: "lineup"}
    data[:lineup_seed_url_value] = seed_path if seed_on_open?
    data
  end

  def seed_on_open?
    @auto_seed && admin && [1, 2].any? { |slot| seed_needed?(slot) }
  end

  def fights
    @fights ||= encounter.team_fights.includes(:kenshi_1, :kenshi_2, :winner, :fight_points).to_a
  end

  def regular_fights
    fights.reject(&:daihyosen?)
  end

  # One card per roster position, whether or not its TeamFight row exists yet.
  # A pool encounter is generated without bouts (they are created on first
  # lineup assign), so we back the missing positions with unsaved placeholders
  # — that gives every position its dropdowns up front, which is how a lineup
  # gets entered now that the form lives in the table.
  def position_rows
    by_position = regular_fights.index_by(&:position)
    (1..encounter.team_size).map do |position|
      by_position[position] || TeamFight.new(encounter: encounter, position: position)
    end
  end

  def daihyosen
    fights.find(&:daihyosen?)
  end

  def teams
    @teams ||= [encounter.resolved_team_1, encounter.resolved_team_2]
  end

  def both_teams_resolved?
    teams.all?(&:present?)
  end

  # Kenshis selectable for each side's dropdown, keyed by team id and loaded once.
  def team_kenshis
    @team_kenshis ||= teams.compact.to_h { |team| [team.id, team.kenshis.to_a] }
  end

  # Pre-fill order for each side, used only while a side's lineup is unset: the
  # dropdowns open showing the team's previous order (or roster order) instead
  # of blank. A set side returns nil so its real picks — including deliberate
  # blanks — are never overridden by a suggestion.
  def suggestions
    @suggestions ||= [1, 2].index_with do |slot|
      next nil unless admin # only the editable (admin) dropdowns use a prefill
      next nil if encounter.public_send(:"lineup_#{slot}_set?")

      EncounterLineupSuggestion.new(encounter).for_slot(slot)
    end
  end

  # Worth seeding this side on open: not yet confirmed, no fighter placed there
  # yet, and there is a suggestion to place. Uses the already-loaded fights so it
  # adds no queries beyond the memoized suggestion.
  private def seed_needed?(slot)
    return false if encounter.public_send(:"lineup_#{slot}_set?")
    return false if suggestions[slot].to_a.compact.empty?

    fights.none? { |fight| !fight.daihyosen? && fight.public_send(:"kenshi_#{slot}_id").present? }
  end

  private def seed_path
    helpers.admin_team_category_encounter_lineup_seed_path(encounter.team_category, encounter)
  end

  def tied?
    result.winner.nil? && both_lineups_in? && encounter.pool_number.blank?
  end

  # Use the authoritative submission flags — NOT fight presence. With only team 1
  # entered, every fight has a kenshi_1 but no kenshi_2, which must not read as a
  # complete (tied) encounter or the daihyōsen prompt appears before team 2 enters.
  def both_lineups_in?
    encounter.lineup_1_set? && encounter.lineup_2_set?
  end

  def fighter_name(kenshi)
    kenshi&.full_name || "—"
  end

  # Mirrors the individual pool fights so the scoring buttons read identically
  # (M/K/D/T/I and △ for hansoku).
  def point_codes
    FightPoint::CODES
  end
end

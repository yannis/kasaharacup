# frozen_string_literal: true

class EncounterComponent < ViewComponent::Base
  include ActionView::RecordIdentifier

  def initialize(encounter:, admin: false)
    @encounter = encounter
    @admin = admin
    @result = encounter.result
  end

  attr_reader :encounter, :admin, :result

  def fights
    @fights ||= encounter.team_fights.includes(:kenshi_1, :kenshi_2, :winner, :fight_points).to_a
  end

  def regular_fights
    fights.reject(&:daihyosen?)
  end

  def daihyosen
    fights.find(&:daihyosen?)
  end

  def tied?
    result.winner.nil? && both_lineups_in?
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
end

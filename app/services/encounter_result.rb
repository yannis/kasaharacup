# frozen_string_literal: true

# Rolls an encounter's TeamFights up to a winning Team, per the rule precedence:
# (1) most individual winners, (2) most points, (3) the daihyosen winner's team
# (else unresolved). kenshi_1 belongs to team_1, kenshi_2 to team_2, so a fight
# won by its kenshi_1 is a team_1 win — forfeits fold in via TeamFight#winner.
class EncounterResult
  def initialize(encounter)
    @encounter = encounter
    @fights = encounter.team_fights.to_a
  end

  def team_1_wins = regular.count { |tf| won_by?(tf, 1) }

  def team_2_wins = regular.count { |tf| won_by?(tf, 2) }

  def team_1_ippons = regular.sum { |tf| tf.individual_points(1) }

  def team_2_ippons = regular.sum { |tf| tf.individual_points(2) }

  def winner
    return @encounter.team_1 if team_1_wins > team_2_wins
    return @encounter.team_2 if team_2_wins > team_1_wins
    return @encounter.team_1 if team_1_ippons > team_2_ippons
    return @encounter.team_2 if team_2_ippons > team_1_ippons

    daihyosen_winner_team
  end

  def team_1_losses = team_2_wins

  def team_2_losses = team_1_wins

  # Bout-level hikiwake count (not the encounter-level draw outcome).
  def draws = regular.count(&:draw)

  # Anchored on the lineup-submission flags (not bout presence): an empty
  # encounter is NOT a draw, and a void trailing bout does not block completeness.
  def complete?
    @encounter.lineup_1_set? && @encounter.lineup_2_set? &&
      regular.all? { |tf| tf.winner_id.present? || tf.draw || tf.void? }
  end

  def outcome_for(team)
    return nil unless complete?
    return nil unless [@encounter.team_1_id, @encounter.team_2_id].include?(team.id)

    w = winner
    return :draw if w.nil?

    (w.id == team.id) ? :win : :loss
  end

  private def regular = @fights.reject(&:daihyosen?)

  private def won_by?(team_fight, slot)
    team_fight.winner_id.present? &&
      team_fight.winner_id == team_fight.public_send(:"kenshi_#{slot}_id")
  end

  private def daihyosen_winner_team
    decider = @fights.find(&:daihyosen?)
    return nil unless decider&.winner_id

    won_by?(decider, 1) ? @encounter.team_1 : @encounter.team_2
  end
end

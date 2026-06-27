# frozen_string_literal: true

# Ranks a team pool by the official 8-level cascade (sibling of PoolStandings).
# Counts only COMPLETE encounters. Residual ties (identical full cascade key) are
# flagged `tied` and left for the admin to break via pool_rank (rep play-offs are
# a deferred phase).
class TeamPoolStandings
  Row = Data.define(:team, :team_wins, :team_losses, :team_hikiwake,
    :individual_wins, :individual_losses, :individual_hikiwake,
    :points_scored, :points_conceded, :rank, :tied)

  # Official 8-level precedence (sorted ascending): "more is better" stats are
  # negated (wins, draws, individual wins/draws, points scored); "less is better"
  # stats stay positive (losses, individual losses, points conceded).
  CASCADE_KEY = ->(r) {
    [-r.team_wins, r.team_losses, -r.team_hikiwake,
      -r.individual_wins, r.individual_losses, -r.individual_hikiwake,
      -r.points_scored, r.points_conceded]
  }

  def self.for(teams:, encounters:)
    new(teams: teams, encounters: encounters.to_a).rows
  end

  def self.persist_ranks!(teams:, encounters:)
    self.for(teams: teams, encounters: encounters).each do |row|
      next if row.rank.nil?
      next if row.team.pool_rank == row.rank

      row.team.update_column(:pool_rank, row.rank) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def initialize(teams:, encounters:)
    @teams = teams
    @encounters = encounters
  end

  private attr_reader :teams, :encounters

  public def rows
    base = teams.map { |team| compute_row(team) }
    return base if no_data?(base)

    ranking = assign_ranks(base)
    base.map { |row|
      info = ranking.fetch(row.team.id)
      row.with(rank: info[:rank], tied: info[:tied])
    }.sort_by(&:rank)
  end

  private def compute_row(team)
    tw = tl = td = iw = il = idr = ps = pc = 0
    completed_for(team).each do |encounter|
      result = result_for(encounter)
      case result.outcome_for(team)
      when :win then tw += 1
      when :loss then tl += 1
      when :draw then td += 1
      end
      slot = (encounter.team_1_id == team.id) ? 1 : 2
      opponent = (slot == 1) ? 2 : 1
      iw += result.public_send(:"team_#{slot}_wins")
      il += result.public_send(:"team_#{slot}_losses")
      idr += result.hikiwake
      ps += result.public_send(:"team_#{slot}_ippons")
      pc += result.public_send(:"team_#{opponent}_ippons")
    end
    Row.new(team: team, team_wins: tw, team_losses: tl, team_hikiwake: td,
      individual_wins: iw, individual_losses: il, individual_hikiwake: idr,
      points_scored: ps, points_conceded: pc, rank: nil, tied: false)
  end

  private def completed_for(team)
    encounters.select do |encounter|
      [encounter.team_1_id, encounter.team_2_id].include?(team.id) && result_for(encounter).complete?
    end
  end

  # One EncounterResult per encounter, shared across every team's row. Each
  # result reads team_fights.to_a once at construction, so caching here avoids
  # rebuilding it O(teams) times per encounter.
  private def result_for(encounter)
    (@results ||= {})[encounter.id] ||= encounter.result
  end

  private def no_data?(rows)
    rows.all? { |r| r.team_wins.zero? && r.team_losses.zero? && r.team_hikiwake.zero? }
  end

  # Distinct sequential ranks; teams sharing an identical full cascade key are
  # flagged tied (no automated play-off — deferred).
  private def assign_ranks(rows)
    sorted = rows.sort_by(&CASCADE_KEY)
    groups = sorted.chunk_while { |a, b| CASCADE_KEY.call(a) == CASCADE_KEY.call(b) }.to_a
    ranking = {}
    cursor = 1
    groups.each do |group|
      tied = group.size > 1
      group.each do |row|
        ranking[row.team.id] = {rank: cursor, tied: tied}
        cursor += 1
      end
    end
    ranking
  end
end

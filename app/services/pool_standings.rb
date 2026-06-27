# frozen_string_literal: true

class PoolStandings
  Row = Data.define(:participation, :wins, :losses, :hikiwake,
    :points_scored, :points_conceded, :rank, :tied)

  CASCADE_KEY = ->(row) {
    [-row.wins, row.losses, -row.hikiwake, -row.points_scored, row.points_conceded]
  }

  def self.for(participations:, fights:)
    new(participations: participations, fights: fights.to_a).rows
  end

  # Recomputes the standings and persists each participation's distinct rank into
  # its pool_rank column (the value that seeds the elimination bracket). Pools
  # without any recorded result are left untouched.
  def self.persist_ranks!(participations:, fights:)
    self.for(participations: participations, fights: fights).each do |row|
      next if row.rank.nil?
      next if row.participation.pool_rank == row.rank

      row.participation.update_column(:pool_rank, row.rank) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def initialize(participations:, fights:)
    @participations = participations
    @fights = fights
  end

  def rows
    base = build_base_rows
    return base if no_data?(base)

    ranking = assign_ranks(base)
    base.map { |row|
      info = ranking.fetch(row.participation.id)
      row.with(rank: info[:rank], tied: info[:tied])
    }.sort_by(&:rank)
  end

  private attr_reader :participations, :fights

  private def no_data?(rows)
    rows.all? do |row|
      row.wins.zero? && row.losses.zero? && row.hikiwake.zero? &&
        row.points_scored.zero? && row.points_conceded.zero?
    end
  end

  private def build_base_rows
    participations.map { |participation| compute_row(participation) }
  end

  private def compute_row(participation)
    kenshi_id = participation.kenshi_id
    wins = 0
    losses = 0
    hikiwake = 0
    points_scored = 0
    points_conceded = 0

    sanbon_fights.each do |fight|
      slot = fighter_slot(fight, kenshi_id)
      next unless slot

      opponent_slot = (slot == 1) ? 2 : 1
      points_scored += fight_points_count(fight, slot)
      points_conceded += fight_points_count(fight, opponent_slot)

      if fight.draw
        hikiwake += 1
      elsif fight.winner_id == kenshi_id
        wins += 1
      elsif fight.winner_id.present?
        losses += 1
      end
    end

    Row.new(participation: participation, wins: wins, losses: losses,
      hikiwake: hikiwake, points_scored: points_scored,
      points_conceded: points_conceded, rank: nil, tied: false)
  end

  private def sanbon_fights
    @sanbon_fights ||= fights.reject(&:tiebreaker)
  end

  private def kettei_sen_fights
    @kettei_sen_fights ||= fights.select(&:tiebreaker)
  end

  private def fighter_slot(fight, kenshi_id)
    return 1 if fight.fighter_1_id == kenshi_id
    return 2 if fight.fighter_2_id == kenshi_id

    nil
  end

  private def fight_points_count(fight, slot)
    side = (slot == 1) ? "fighter_1" : "fighter_2"
    fight.fight_points.count { |p| p.fighter_side == side && p.kind != "hansoku" }
  end

  # Returns participation_id => {rank:, tied:}. Every participation gets a
  # distinct sequential rank (so the value can seed a bracket), while `tied`
  # marks the rows whose order within their standings group is arbitrary —
  # i.e. a genuine tie that no kettei-sen fight resolved.
  private def assign_ranks(rows)
    sorted = rows.sort_by(&CASCADE_KEY)
    groups = sorted.chunk_while { |a, b| CASCADE_KEY.call(a) == CASCADE_KEY.call(b) }.to_a

    ranking = {}
    cursor = 1
    groups.each do |group|
      resolved = resolve_pair_with_kettei_sen(group)
      tied = group.size > 1 && resolved.nil?
      (resolved || group).each do |row|
        ranking[row.participation.id] = {rank: cursor, tied: tied}
        cursor += 1
      end
    end

    ranking
  end

  # Returns an ordered [winner, loser] array when a 2-way tie is resolved by
  # a kettei-sen fight with a winner; returns nil otherwise (including for
  # groups of 3+ and unresolved/draw kettei-sen).
  private def resolve_pair_with_kettei_sen(group)
    return nil unless group.size == 2

    a, b = group
    fight = kettei_sen_between(a.participation.kenshi_id, b.participation.kenshi_id)
    return nil if fight.nil? || fight.winner_id.blank?

    (fight.winner_id == a.participation.kenshi_id) ? [a, b] : [b, a]
  end

  private def kettei_sen_between(kenshi_a_id, kenshi_b_id)
    kettei_sen_fights.find { |fight|
      ids = [fight.fighter_1_id, fight.fighter_2_id]
      ids.include?(kenshi_a_id) && ids.include?(kenshi_b_id)
    }
  end
end

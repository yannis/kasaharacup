# frozen_string_literal: true

class PoolStandings
  Row = Data.define(:participation, :wins, :losses, :hikiwake,
    :points_scored, :points_conceded, :suggested_rank)

  CASCADE_KEY = ->(row) {
    [-row.wins, row.losses, -row.hikiwake]
  }

  def self.for(participations:, fights:)
    new(participations: participations, fights: fights.to_a).rows
  end

  def initialize(participations:, fights:)
    @participations = participations
    @fights = fights
  end

  def rows
    base = build_base_rows
    rank_by_participation_id = assign_ranks(base)
    base.map { |row|
      Row.new(**row.to_h.except(:suggested_rank),
        suggested_rank: rank_by_participation_id.fetch(row.participation.id))
    }.sort_by(&:suggested_rank)
  end

  private attr_reader :participations, :fights

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
      points_conceded: points_conceded, suggested_rank: nil)
  end

  private def sanbon_fights
    @sanbon_fights ||= fights.reject(&:tiebreaker)
  end

  private def tiebreaker_fights
    @tiebreaker_fights ||= fights.select(&:tiebreaker)
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

  private def assign_ranks(rows)
    sorted = rows.sort_by(&CASCADE_KEY)
    groups = sorted.chunk_while { |a, b| CASCADE_KEY.call(a) == CASCADE_KEY.call(b) }.to_a

    rank_by_participation_id = {}
    cursor = 1
    groups.each do |group|
      ordered = resolve_pair_with_tiebreaker(group)
      if ordered
        ordered.each_with_index do |row, index|
          rank_by_participation_id[row.participation.id] = cursor + index
        end
      else
        group.each { |row| rank_by_participation_id[row.participation.id] = cursor }
      end
      cursor += group.size
    end

    rank_by_participation_id
  end

  # Returns an ordered [winner, loser] array when a 2-way tie is resolved by
  # a tiebreaker fight with a winner; returns nil otherwise (including for
  # groups of 3+ and unresolved/draw tiebreakers).
  private def resolve_pair_with_tiebreaker(group)
    return nil unless group.size == 2

    a, b = group
    fight = tiebreaker_between(a.participation.kenshi_id, b.participation.kenshi_id)
    return nil if fight.nil? || fight.winner_id.blank?

    (fight.winner_id == a.participation.kenshi_id) ? [a, b] : [b, a]
  end

  private def tiebreaker_between(kenshi_a_id, kenshi_b_id)
    tiebreaker_fights.find { |fight|
      ids = [fight.fighter_1_id, fight.fighter_2_id]
      ids.include?(kenshi_a_id) && ids.include?(kenshi_b_id)
    }
  end
end

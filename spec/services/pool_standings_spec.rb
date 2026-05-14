# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoolStandings do
  let(:cup) { create(:cup) }
  let(:category) { create(:individual_category, cup: cup) }

  def participate(pool:, position:)
    kenshi = create(:kenshi, cup: cup)
    p = create(:participation, category: category, kenshi: kenshi,
      pool_number: pool, pool_position: position)
    [p, kenshi]
  end

  def record_fight(kenshi_a, kenshi_b, winner: nil, draw: false, points_a: 0, points_b: 0, tiebreaker: false)
    fight = create(:fight, :pool_fight, individual_category: category, pool_number: 1,
      fighter_1: kenshi_a, fighter_2: kenshi_b,
      tiebreaker: tiebreaker, draw: draw, winner: winner)
    points_a.times { create(:fight_point, fight: fight, fighter_side: "fighter_1", kind: "men") }
    points_b.times { create(:fight_point, fight: fight, fighter_side: "fighter_2", kind: "men") }
    fight
  end

  describe ".for(participations:, fights:)" do
    it "tallies wins, losses, hikiwake, points scored, points conceded" do
      p1, k1 = participate(pool: 1, position: 1)
      p2, k2 = participate(pool: 1, position: 2)
      p3, k3 = participate(pool: 1, position: 3)
      record_fight(k1, k2, winner: k1, points_a: 2, points_b: 1)
      record_fight(k2, k3, draw: true, points_a: 1, points_b: 1)
      record_fight(k1, k3, winner: k1, points_a: 2, points_b: 0)

      rows = described_class.for(participations: [p1, p2, p3], fights: category.pool_fights)

      expect(rows.find { |r| r.participation == p1 }).to have_attributes(
        wins: 2, losses: 0, hikiwake: 0, points_scored: 4, points_conceded: 1, suggested_rank: 1
      )
      expect(rows.find { |r| r.participation == p2 }).to have_attributes(
        wins: 0, losses: 1, hikiwake: 1, points_scored: 2, points_conceded: 3, suggested_rank: 2
      )
      expect(rows.find { |r| r.participation == p3 }).to have_attributes(
        wins: 0, losses: 1, hikiwake: 1, points_scored: 1, points_conceded: 3, suggested_rank: 3
      )
    end

    it "excludes tiebreaker fights from W/L/H tallies but uses them to break a 2-way tie" do
      p1, k1 = participate(pool: 1, position: 1)
      p2, k2 = participate(pool: 1, position: 2)
      p3, k3 = participate(pool: 1, position: 3)
      record_fight(k1, k2, draw: true, points_a: 0, points_b: 0)
      record_fight(k2, k3, winner: k2, points_a: 2, points_b: 0)
      record_fight(k1, k3, winner: k1, points_a: 2, points_b: 0)
      record_fight(k1, k2, winner: k2, tiebreaker: true)

      rows = described_class.for(participations: [p1, p2, p3], fights: category.pool_fights)

      expect(rows.find { |r| r.participation == p1 }).to have_attributes(
        wins: 1, losses: 0, hikiwake: 1, suggested_rank: 2
      )
      expect(rows.find { |r| r.participation == p2 }).to have_attributes(
        wins: 1, losses: 0, hikiwake: 1, suggested_rank: 1
      )
      expect(rows.find { |r| r.participation == p3 }).to have_attributes(suggested_rank: 3)
    end

    it "keeps an unresolved 2-way tie equal when the tiebreaker is a draw" do
      p1, k1 = participate(pool: 1, position: 1)
      p2, k2 = participate(pool: 1, position: 2)
      p3, k3 = participate(pool: 1, position: 3)
      record_fight(k1, k2, draw: true, points_a: 0, points_b: 0)
      record_fight(k2, k3, winner: k2, points_a: 2, points_b: 0)
      record_fight(k1, k3, winner: k1, points_a: 2, points_b: 0)
      record_fight(k1, k2, draw: true, tiebreaker: true)

      rows = described_class.for(participations: [p1, p2, p3], fights: category.pool_fights)

      tied = rows.select { |r| [p1, p2].include?(r.participation) }
      expect(tied.map(&:suggested_rank)).to eq [1, 1]
      expect(rows.find { |r| r.participation == p3 }.suggested_rank).to eq 3
    end

    it "leaves a 3-way tie equal even without a tiebreaker fight" do
      p1, k1 = participate(pool: 1, position: 1)
      p2, k2 = participate(pool: 1, position: 2)
      p3, k3 = participate(pool: 1, position: 3)
      record_fight(k1, k2, draw: true)
      record_fight(k2, k3, draw: true)
      record_fight(k1, k3, draw: true)

      rows = described_class.for(participations: [p1, p2, p3], fights: category.pool_fights)

      expect(rows.map(&:suggested_rank)).to eq [1, 1, 1]
    end

    it "applies the full 5-criterion cascade (wins/losses/hikiwake/points_scored/points_conceded)" do
      p1, k1 = participate(pool: 1, position: 1)
      p2, k2 = participate(pool: 1, position: 2)
      record_fight(k1, k2, winner: k1, points_a: 2, points_b: 0)
      _, k3 = participate(pool: 1, position: 3)
      record_fight(k1, k3, draw: true, points_a: 1, points_b: 1)
      record_fight(k2, k3, draw: true, points_a: 1, points_b: 2)

      rows = described_class.for(participations: [p1, p2], fights: category.pool_fights)

      expect(rows.find { |r| r.participation == p1 }.suggested_rank).to eq 1
      expect(rows.find { |r| r.participation == p2 }.suggested_rank).to eq 2
    end
  end
end

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
    points_a.times { create(:fight_point, scorable: fight, fighter_side: "fighter_1", kind: "men") }
    points_b.times { create(:fight_point, scorable: fight, fighter_side: "fighter_2", kind: "men") }
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
        wins: 2, losses: 0, hikiwake: 0, points_scored: 4, points_conceded: 1, rank: 1, tied: false
      )
      expect(rows.find { |r| r.participation == p2 }).to have_attributes(
        wins: 0, losses: 1, hikiwake: 1, points_scored: 2, points_conceded: 3, rank: 2, tied: false
      )
      expect(rows.find { |r| r.participation == p3 }).to have_attributes(
        wins: 0, losses: 1, hikiwake: 1, points_scored: 1, points_conceded: 3, rank: 3, tied: false
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
        wins: 1, losses: 0, hikiwake: 1, rank: 2, tied: false
      )
      expect(rows.find { |r| r.participation == p2 }).to have_attributes(
        wins: 1, losses: 0, hikiwake: 1, rank: 1, tied: false
      )
      expect(rows.find { |r| r.participation == p3 }).to have_attributes(rank: 3, tied: false)
    end

    it "assigns distinct ranks and flags ties when a 2-way tiebreaker is a draw" do
      p1, k1 = participate(pool: 1, position: 1)
      p2, k2 = participate(pool: 1, position: 2)
      p3, k3 = participate(pool: 1, position: 3)
      record_fight(k1, k2, draw: true, points_a: 0, points_b: 0)
      record_fight(k2, k3, winner: k2, points_a: 2, points_b: 0)
      record_fight(k1, k3, winner: k1, points_a: 2, points_b: 0)
      record_fight(k1, k2, draw: true, tiebreaker: true)

      rows = described_class.for(participations: [p1, p2, p3], fights: category.pool_fights)

      tied = rows.select { |r| [p1, p2].include?(r.participation) }
      expect(tied.map(&:rank)).to contain_exactly(1, 2)
      expect(tied.map(&:tied)).to eq [true, true]
      expect(rows.find { |r| r.participation == p3 }).to have_attributes(rank: 3, tied: false)
    end

    it "leaves rank nil for all rows when no fight has results yet" do
      p1, k1 = participate(pool: 1, position: 1)
      p2, k2 = participate(pool: 1, position: 2)
      p3, k3 = participate(pool: 1, position: 3)
      create(:fight, :pool_fight, individual_category: category, pool_number: 1,
        fighter_1: k1, fighter_2: k2)
      create(:fight, :pool_fight, individual_category: category, pool_number: 1,
        fighter_1: k2, fighter_2: k3)

      rows = described_class.for(participations: [p1, p2, p3], fights: category.pool_fights)

      expect(rows.map(&:rank)).to eq [nil, nil, nil]
      expect(rows.map(&:tied)).to eq [false, false, false]
    end

    it "assigns distinct ranks to a 3-way tie and flags every member as tied" do
      p1, k1 = participate(pool: 1, position: 1)
      p2, k2 = participate(pool: 1, position: 2)
      p3, k3 = participate(pool: 1, position: 3)
      record_fight(k1, k2, draw: true)
      record_fight(k2, k3, draw: true)
      record_fight(k1, k3, draw: true)

      rows = described_class.for(participations: [p1, p2, p3], fights: category.pool_fights)

      expect(rows.map(&:rank)).to contain_exactly(1, 2, 3)
      expect(rows.map(&:tied)).to eq [true, true, true]
    end

    it "applies the full 5-criterion cascade (wins/losses/hikiwake/points_scored/points_conceded)" do
      p1, k1 = participate(pool: 1, position: 1)
      p2, k2 = participate(pool: 1, position: 2)
      record_fight(k1, k2, winner: k1, points_a: 2, points_b: 0)
      _, k3 = participate(pool: 1, position: 3)
      record_fight(k1, k3, draw: true, points_a: 1, points_b: 1)
      record_fight(k2, k3, draw: true, points_a: 1, points_b: 2)

      rows = described_class.for(participations: [p1, p2], fights: category.pool_fights)

      expect(rows.find { |r| r.participation == p1 }.rank).to eq 1
      expect(rows.find { |r| r.participation == p2 }.rank).to eq 2
    end
  end

  describe ".persist_ranks!(participations:, fights:)" do
    it "writes the computed distinct ranks into each participation's pool_rank" do
      p1, k1 = participate(pool: 1, position: 1)
      p2, k2 = participate(pool: 1, position: 2)
      p3, k3 = participate(pool: 1, position: 3)
      record_fight(k1, k2, winner: k1, points_a: 2, points_b: 0)
      record_fight(k1, k3, winner: k1, points_a: 2, points_b: 0)
      record_fight(k2, k3, winner: k2, points_a: 2, points_b: 0)

      described_class.persist_ranks!(participations: [p1, p2, p3], fights: category.pool_fights)

      expect(p1.reload.pool_rank).to eq 1
      expect(p2.reload.pool_rank).to eq 2
      expect(p3.reload.pool_rank).to eq 3
    end

    it "overwrites a previous manual pool_rank with the freshly computed value" do
      p1, k1 = participate(pool: 1, position: 1)
      p2, k2 = participate(pool: 1, position: 2)
      p1.update!(pool_rank: 2)
      p2.update!(pool_rank: 1)
      record_fight(k1, k2, winner: k1, points_a: 2, points_b: 0)

      described_class.persist_ranks!(participations: [p1, p2], fights: category.pool_fights)

      expect(p1.reload.pool_rank).to eq 1
      expect(p2.reload.pool_rank).to eq 2
    end

    it "leaves pool_rank untouched when no fight has results yet" do
      p1, k1 = participate(pool: 1, position: 1)
      p2, k2 = participate(pool: 1, position: 2)
      p1.update!(pool_rank: 1)
      p2.update!(pool_rank: 2)
      create(:fight, :pool_fight, individual_category: category, pool_number: 1,
        fighter_1: k1, fighter_2: k2)

      described_class.persist_ranks!(participations: [p1, p2], fights: category.pool_fights)

      expect(p1.reload.pool_rank).to eq 1
      expect(p2.reload.pool_rank).to eq 2
    end
  end
end

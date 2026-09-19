# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamPooler do
  let(:tc) { create(:team_category, pool_size: 3) }

  def team(seed: nil) = create(:team, team_category: tc, seed: seed)

  it "puts the seeded teams into distinct pools" do
    seeds = [team(seed: 1), team(seed: 2), team(seed: 3), team(seed: 4)]
    8.times { team }

    described_class.new(tc, random: Random.new(1)).set_pools

    pool_numbers = seeds.map { |s| s.reload.pool_number }
    expect(pool_numbers.uniq.size).to eq 4 # all in different pools
  end

  # The regression #1312 asks for. Distinct pools was never the hard part —
  # consecutive pool numbers are exactly the ones BracketSeeder.low_block sends
  # to the SAME half, so the old `i % pool_count` put seeds 1 and 2 both in the
  # top half and they met in the semifinal.
  #
  # Reads the encounters' own pool_number/pool_rank rather than playing out a
  # pool phase: the builder records them even with no rank entered, and round-1
  # encounters in position order are the bracket left to right, so the first
  # half of the column is the top half of the tree.
  describe "keeping the seeds apart in the bracket" do
    # out_of_pool is what makes the builder emit round-1 slots at all; the
    # bare factory leaves it nil.
    let(:tc) { create(:team_category, pool_size: 3, out_of_pool: 2) }

    def half_of(pool_number)
      encounters = tc.bracket_encounters.where(round: 1).order(:position).to_a
      index = encounters.index { |encounter|
        [[encounter.team_1_pool_number, encounter.team_1_pool_rank],
          [encounter.team_2_pool_number, encounter.team_2_pool_rank]].include?([pool_number, 1])
      }
      (index < encounters.size / 2) ? :top : :bottom
    end

    it "sends the top two seeds' pools to opposite halves" do
      first = team(seed: 1)
      second = team(seed: 2)
      10.times { team }

      described_class.new(tc, random: Random.new(1)).set_pools
      TeamCategoryBracketBuilder.new(tc).call

      expect(half_of(first.reload.pool_number)).not_to eq half_of(second.reload.pool_number)
    end

    it "splits four seeds two to a half" do
      seeds = Array.new(4) { |i| team(seed: i + 1) }
      12.times { team }

      described_class.new(tc, random: Random.new(1)).set_pools
      TeamCategoryBracketBuilder.new(tc).call

      halves = seeds.map { |s| half_of(s.reload.pool_number) }
      expect(halves.tally.values.sort).to eq [2, 2]
      # And the standard pairing below the top two: 1 meets 4, 2 meets 3.
      expect(halves[0]).to eq halves[3]
      expect(halves[1]).to eq halves[2]
    end
  end

  it "sizes pools with the fewest short pools (11 teams, size 3 -> 3,3,3,2)" do
    11.times { team }
    described_class.new(tc, random: Random.new(1)).set_pools

    sizes = tc.teams.where.not(pool_number: nil).group_by(&:pool_number).values.map(&:size).sort
    expect(sizes).to eq [2, 3, 3, 3]
  end

  it "assigns a 1-based pool_position within each pool" do
    6.times { team }
    described_class.new(tc, random: Random.new(1)).set_pools

    tc.team_pools.each do |pool|
      expect(pool.teams.map(&:pool_position)).to eq (1..pool.teams.size).to_a
    end
  end

  it "is deterministic for a given seed" do
    9.times { team }
    described_class.new(tc, random: Random.new(42)).set_pools
    first = tc.teams.order(:id).map(&:pool_number)

    described_class.new(tc, random: Random.new(42)).set_pools
    expect(tc.teams.order(:id).reload.map(&:pool_number)).to eq first
  end

  it "clears pool assignments when pool_size <= 1" do
    single = create(:team_category, pool_size: 1)
    t = create(:team, team_category: single, pool_number: 1, pool_position: 1)

    described_class.new(single).set_pools

    expect(t.reload.pool_number).to be_nil
  end
end

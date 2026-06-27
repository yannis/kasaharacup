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

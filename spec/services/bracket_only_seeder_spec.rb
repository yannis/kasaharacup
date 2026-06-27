# frozen_string_literal: true

require "rails_helper"

RSpec.describe BracketOnlySeeder do
  let(:cup) { create(:cup) }
  let(:category) { create(:team_category, cup: cup, pool_size: nil) }

  # seeds: maps team index -> seed value, e.g. {0 => 1, 1 => 2}
  def make_teams(count, seeds: {})
    Array.new(count) { |i| create(:team, team_category: category, seed: seeds[i]) }
  end

  def flat(pairs)
    pairs.flatten.compact
  end

  it "returns no pairs for 0 or 1 team" do
    expect(described_class.new([]).first_round_pairs).to eq []
    expect(described_class.new(make_teams(1)).first_round_pairs).to eq []
  end

  it "pairs 2 teams into a single fight with no byes" do
    teams = make_teams(2)
    pairs = described_class.new(teams, random: Random.new(1)).first_round_pairs

    expect(pairs.size).to eq 1
    expect(flat(pairs)).to match_array teams
  end

  it "never duplicates or drops a team and pads to a power of two" do
    [3, 5, 8, 9].each do |n|
      teams = make_teams(n)
      seeder = described_class.new(teams, random: Random.new(7))
      pairs = seeder.first_round_pairs

      expect(pairs.size).to eq seeder.bracket_size / 2
      expect(flat(pairs)).to match_array teams
    end
  end

  it "gives byes to seeded teams first" do
    teams = make_teams(6, seeds: {0 => 1, 1 => 2}) # bracket of 8 -> 2 byes
    pairs = described_class.new(teams, random: Random.new(3)).first_round_pairs

    bye_recipients = pairs.filter_map { |pair| pair.first if pair[1].nil? }
    expect(bye_recipients).to contain_exactly(teams[0], teams[1])
  end

  it "spreads byes so no two byes meet in round 2 when avoidable" do
    teams = make_teams(12) # bracket of 16 -> 4 byes across 8 units
    pairs = described_class.new(teams, random: Random.new(3)).first_round_pairs

    pairs.each_slice(2) do |unit_a, unit_b|
      expect([unit_a, unit_b].count { |pair| pair[1].nil? }).to be <= 1
    end
  end

  it "fills remaining byes with random unseeded teams after the seeds" do
    teams = make_teams(5, seeds: {0 => 1}) # bracket of 8 -> 3 byes
    pairs = described_class.new(teams, random: Random.new(3)).first_round_pairs

    bye_recipients = pairs.filter_map { |pair| pair.first if pair[1].nil? }
    expect(bye_recipients.size).to eq 3
    expect(bye_recipients).to include teams[0]
  end

  it "places seed 1 in the first unit and seed 2 in the last" do
    teams = make_teams(8, seeds: {0 => 1, 1 => 2})
    pairs = described_class.new(teams, random: Random.new(3)).first_round_pairs

    expect(pairs.first).to include teams[0]
    expect(pairs.last).to include teams[1]
  end

  it "places seeds 3 and 4 at the quarter boundaries, projecting 1v4 and 2v3 semis" do
    teams = make_teams(8, seeds: {0 => 1, 1 => 2, 2 => 3, 3 => 4})
    pairs = described_class.new(teams, random: Random.new(3)).first_round_pairs

    expect(pairs[1]).to include teams[3] # seed 4 shares the top half with seed 1
    expect(pairs[2]).to include teams[2] # seed 3 shares the bottom half with seed 2
  end

  it "places seeds beyond 4 at the next protected positions" do
    teams = make_teams(16, seeds: {0 => 1, 1 => 2, 2 => 3, 3 => 4, 4 => 5})
    pairs = described_class.new(teams, random: Random.new(3)).first_round_pairs

    # standard layout for 8 units is [1, 8, 4, 5, 6, 3, 7, 2] -> seed 5 at unit 3,
    # projecting the 4v5 quarterfinal
    expect(pairs[3]).to include teams[4]
  end

  it "pairs each non-bye seed against an unseeded team while any remain" do
    teams = make_teams(8, seeds: {0 => 1, 1 => 2})
    pairs = described_class.new(teams, random: Random.new(3)).first_round_pairs

    [teams[0], teams[1]].each do |seed|
      pair = pairs.find { |p| p.include?(seed) }
      opponent = (pair - [seed]).first
      expect(opponent.seed).to be_nil
    end
  end

  it "pairs leftover seeds strongest vs weakest in an all-seeded field" do
    teams = make_teams(4, seeds: {0 => 1, 1 => 2, 2 => 3, 3 => 4})
    pairs = described_class.new(teams, random: Random.new(3)).first_round_pairs

    expect(pairs).to eq [[teams[0], teams[3]], [teams[1], teams[2]]]
  end

  it "breaks duplicate seed values deterministically by id" do
    teams = make_teams(4, seeds: {0 => 1, 1 => 1})
    pairs = described_class.new(teams, random: Random.new(5)).first_round_pairs

    expect(pairs.first).to include teams[0] # lower id takes the top spot
    expect(pairs.last).to include teams[1]
  end

  it "is deterministic for a given RNG with no seeded teams" do
    teams = make_teams(8)
    # Two seeder instances with equal RNG seeds: not an identical expression.
    first_draw = described_class.new(teams, random: Random.new(11)).first_round_pairs
    second_draw = described_class.new(teams, random: Random.new(11)).first_round_pairs
    expect(second_draw).to eq first_draw # rubocop:disable RSpec/IdenticalEqualityAssertion
  end
end

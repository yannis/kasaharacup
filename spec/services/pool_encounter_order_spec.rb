# frozen_string_literal: true

require "rails_helper"

RSpec.describe PoolEncounterOrder do
  let(:cup) { create(:cup) }
  let(:category) { create(:team_category, cup: cup, team_size: 3, pool_size: 3, out_of_pool: 1) }

  # Pools::CyclicPairing draws one tie per team in a pool of three or more, and
  # a single tie in a pool of two.
  def pool_of(number, team_count)
    team_count.times do |index|
      create(:team, team_category: category, pool_number: number, pool_position: index + 1)
    end
  end

  def places_of(ties)
    ties.map { |tie| [tie.pool_number, tie.position] }
  end

  it "takes one tie from each pool in turn" do
    pool_of(1, 3)
    pool_of(2, 3)
    PoolEncounterGenerator.new(category).call

    expect(places_of(described_class.new(category).call))
      .to eq [[1, 1], [2, 1], [1, 2], [2, 2], [1, 3], [2, 3]]
  end

  it "interleaves the pools two at a time, so a pool's ties stay close together" do
    4.times { |index| pool_of(index + 1, 3) }
    PoolEncounterGenerator.new(category).call

    # One tie of rest between a team's own two, not one from every pool in the
    # category: pool 1 is done before pool 3 starts.
    expect(places_of(described_class.new(category).call)).to eq [
      [1, 1], [2, 1], [1, 2], [2, 2], [1, 3], [2, 3],
      [3, 1], [4, 1], [3, 2], [4, 2], [3, 3], [4, 3]
    ]
  end

  it "gives a pool left over by the pairing the company of the pair before it" do
    3.times { |index| pool_of(index + 1, 3) }
    PoolEncounterGenerator.new(category).call

    # In a group of its own pool 3 would fight its three ties back to back, so
    # it joins the last pair and the three interleave.
    expect(places_of(described_class.new(category).call)).to eq [
      [1, 1], [2, 1], [3, 1], [1, 2], [2, 2], [3, 2], [1, 3], [2, 3], [3, 3]
    ]
  end

  it "numbers the ties 1..N in fighting order" do
    pool_of(1, 3)
    pool_of(2, 3)
    PoolEncounterGenerator.new(category).call

    expect(described_class.new(category).call.map(&:order)).to eq (1..6).to_a
  end

  # The whole point of the interleave: with another pool's tie between them, a
  # team's two appearances are never back to back.
  it "keeps a team off the court in the tie that follows its own" do
    pool_of(1, 3)
    pool_of(2, 3)
    PoolEncounterGenerator.new(category).call

    ties = described_class.new(category).call
    teams_of = ->(tie) { [tie.encounter.team_1_id, tie.encounter.team_2_id] }
    back_to_back = ties.each_cons(2).select do |first, second|
      teams_of.call(first).intersect?(teams_of.call(second))
    end

    expect(back_to_back).to be_empty
  end

  # A pool of two has one tie, so from the second round on there is nothing
  # left to interpose and pool 1's last ties follow one another.
  it "trails an uneven pool's remaining ties at the end" do
    pool_of(1, 3)
    pool_of(2, 2)
    PoolEncounterGenerator.new(category).call

    expect(places_of(described_class.new(category).call))
      .to eq [[1, 1], [2, 1], [1, 2], [1, 3]]
  end

  it "keeps a single pool in the order it was drawn" do
    pool_of(1, 3)
    PoolEncounterGenerator.new(category).call

    expect(described_class.new(category).call.map { |tie| tie.encounter.id })
      .to eq category.encounters.order(:id).pluck(:id)
  end

  it "labels a tie with its pool and its place in that pool" do
    pool_of(1, 3)
    pool_of(2, 2)
    PoolEncounterGenerator.new(category).call

    expect(described_class.new(category).call.map(&:label))
      .to eq ["Pool 1 — 1/3", "Pool 2 — 1/1", "Pool 1 — 2/3", "Pool 1 — 3/3"]
  end

  it "reads the ties off the encounter records rather than the pairing formula" do
    pool_of(1, 3)
    PoolEncounterGenerator.new(category).call
    # In the category but in no pool, so no pairing computed over pool 1's
    # teams could ever name it. Only the record can.
    outsider = create(:team, team_category: category, name: "Outsider", pool_number: nil)
    category.encounters.order(:id).first.update!(team_1: outsider)

    expect(described_class.new(category).call.first.encounter.team_1).to eq outsider
  end

  it "returns nothing for a category whose pools have no encounters yet" do
    pool_of(1, 3)

    expect(described_class.new(category).call).to eq []
  end
end

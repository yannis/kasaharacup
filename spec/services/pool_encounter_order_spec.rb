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

  def positions_of(ties)
    ties.map { |tie| [tie.encounter.team_1, tie.encounter.team_2].map(&:pool_position).sort }
  end

  it "fights the pools one after the other" do
    pool_of(1, 3)
    pool_of(2, 3)
    PoolEncounterGenerator.new(category).call

    expect(places_of(described_class.new(category).call))
      .to eq [[1, 1], [1, 2], [1, 3], [2, 1], [2, 2], [2, 3]]
  end

  # Pools::CyclicPairing draws a pool of three as (1,2), (3,2), (3,1).
  it "orders a pool's ties 1 <> 2, 1 <> 3, 2 <> 3" do
    pool_of(1, 3)
    PoolEncounterGenerator.new(category).call

    expect(positions_of(described_class.new(category).call)).to eq [[1, 2], [1, 3], [2, 3]]
  end

  it "keeps the sides the encounter record gives a tie" do
    pool_of(1, 3)
    PoolEncounterGenerator.new(category).call
    drawn = category.encounters.to_h { |encounter| [encounter.id, [encounter.team_1_id, encounter.team_2_id]] }

    ties = described_class.new(category).call

    expect(ties.to_h { |tie| [tie.encounter.id, [tie.encounter.team_1_id, tie.encounter.team_2_id]] }).to eq drawn
  end

  it "numbers the ties 1..N in fighting order" do
    pool_of(1, 3)
    pool_of(2, 3)
    PoolEncounterGenerator.new(category).call

    expect(described_class.new(category).call.map(&:order)).to eq (1..6).to_a
  end

  it "puts a tie with a team moved out of the pool at the end of that pool" do
    pool_of(1, 3)
    PoolEncounterGenerator.new(category).call
    # The first tie is 2 <> 1; without its red team 1 it sorts as 2 <> nothing,
    # after the 2 <> 3 that follows it.
    first = category.encounters.order(:id).first
    first.update!(team_2: create(:team, team_category: category, pool_number: nil))

    expect(described_class.new(category).call.last.encounter).to eq first
  end

  it "labels a tie with its pool and its place in that pool", :en do
    pool_of(1, 3)
    pool_of(2, 2)
    PoolEncounterGenerator.new(category).call

    expect(described_class.new(category).call.map(&:label))
      .to eq ["Pool 1 — 1/3", "Pool 1 — 2/3", "Pool 1 — 3/3", "Pool 2 — 1/1"]
  end

  it "names the pool in the language of the session", :fr do
    pool_of(1, 3)
    PoolEncounterGenerator.new(category).call

    expect(described_class.new(category).call.first.label).to eq "Poule 1 — 1/3"
  end

  it "reads the ties off the encounter records rather than the pairing formula" do
    pool_of(1, 3)
    PoolEncounterGenerator.new(category).call
    # In the category but in no pool, so no pairing computed over pool 1's
    # teams could ever name it. Only the record can.
    outsider = create(:team, team_category: category, name: "Outsider", pool_number: nil)
    tie = category.encounters.order(:id).first
    tie.update!(team_1: outsider)

    expect(described_class.new(category).call.find { |row| row.encounter.id == tie.id }.encounter.team_1)
      .to eq outsider
  end

  it "returns nothing for a category whose pools have no encounters yet" do
    pool_of(1, 3)

    expect(described_class.new(category).call).to eq []
  end
end

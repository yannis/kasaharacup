# frozen_string_literal: true

require "rails_helper"

RSpec.describe EncounterLineupSeeder do
  let(:tc) { create(:team_category, team_size: 3) }
  let(:t1) { create(:team, team_category: tc) }
  let(:t2) { create(:team, team_category: tc) }

  def members(team, count)
    create_list(:kenshi, count, cup: tc.cup).each do |k|
      create(:participation, category: tc, team: team, kenshi: k)
    end
  end

  it "seeds both sides from their previous order and confirms them" do
    a = members(t1, 3)
    b = members(t2, 3)
    prev1 = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    EncounterLineup.new(prev1).assign(t1, [a[1].id, a[0].id, a[2].id])
    EncounterLineup.new(prev1).assign(t2, b.map(&:id))

    fresh = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    described_class.new(fresh).call

    fights = fresh.team_fights.order(:position)
    expect(fights.map(&:kenshi_1_id)).to eq [a[1].id, a[0].id, a[2].id]
    expect(fights.map(&:kenshi_2_id)).to eq b.map(&:id)
    # Seeding confirms, so an opened encounter is immediately usable.
    expect(fresh.reload.lineup_1_set?).to be true
    expect(fresh.lineup_2_set?).to be true
  end

  it "falls back to roster order for a team with no history" do
    roster = members(t1, 3)
    members(t2, 3)
    fresh = create(:encounter, team_category: tc, team_1: t1, team_2: t2)

    described_class.new(fresh).call

    expect(fresh.team_fights.order(:position).map(&:kenshi_1_id)).to eq roster.map(&:id)
  end

  it "leaves an already-confirmed side untouched" do
    a = members(t1, 3)
    members(t2, 3)
    fresh = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    EncounterLineup.new(fresh).assign(t1, [a[2].id, a[1].id, a[0].id])

    described_class.new(fresh).call

    # The confirmed order stands; seeding doesn't overwrite it.
    expect(fresh.team_fights.order(:position).map(&:kenshi_1_id)).to eq [a[2].id, a[1].id, a[0].id]
    expect(fresh.reload.lineup_1_set?).to be true
  end

  it "does not re-seed a side it already filled" do
    a = members(t1, 3)
    members(t2, 3)
    fresh = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    described_class.new(fresh).call # first seed lays down + confirms roster order
    reordered = a.reverse

    # A manual reorder of the already-filled side; a second call must not overwrite it.
    EncounterLineup.new(fresh).assign(t1, reordered.map(&:id))
    described_class.new(fresh).call

    expect(fresh.team_fights.order(:position).map(&:kenshi_1_id)).to eq reordered.map(&:id)
  end

  it "is a no-op for a team with no members" do
    members(t2, 3)
    fresh = create(:encounter, team_category: tc, team_1: t1, team_2: t2)

    expect { described_class.new(fresh).call }.not_to raise_error
    expect(fresh.team_fights.map(&:kenshi_1_id)).to all(be_nil)
  end
end

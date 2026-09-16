# frozen_string_literal: true

require "rails_helper"

RSpec.describe EncounterLineupSuggestion do
  let(:tc) { create(:team_category, team_size: 3) }
  let(:t1) { create(:team, team_category: tc) }
  let(:t2) { create(:team, team_category: tc) }

  def members(team, count)
    create_list(:kenshi, count, cup: tc.cup).each do |k|
      create(:participation, category: tc, team: team, kenshi: k)
    end
  end

  it "suggests the order the team used in its previous encounter" do
    roster = members(t1, 3)
    members(t2, 3)
    order = [roster[2], roster[0], roster[1]]

    previous = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    EncounterLineup.new(previous).assign(t1, order.map(&:id))

    fresh = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    expect(described_class.new(fresh).for_slot(1)).to eq order.map(&:id)
  end

  it "carries forward a forfeit gap from the previous order" do
    roster = members(t1, 3)
    members(t2, 3)

    previous = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    EncounterLineup.new(previous).assign(t1, [roster[0].id, nil, roster[2].id])

    fresh = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    expect(described_class.new(fresh).for_slot(1)).to eq [roster[0].id, nil, roster[2].id]
  end

  it "matches the team regardless of which side it sat on previously" do
    roster = members(t2, 3)
    members(t1, 3)

    # t2 was on side 2 before; suggesting for its side here must still find it.
    previous = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    EncounterLineup.new(previous).assign(t2, roster.map(&:id))

    fresh = create(:encounter, team_category: tc, team_1: t2, team_2: t1)
    expect(described_class.new(fresh).for_slot(1)).to eq roster.map(&:id)
  end

  it "falls back to stable roster order when the team has no previous encounter" do
    kenshis = create_list(:kenshi, 3, cup: tc.cup)
    roster = [kenshis.second, kenshis.first, kenshis.third]
    roster.each { |kenshi| create(:participation, category: tc, team: t1, kenshi: kenshi) }
    members(t2, 3)

    fresh = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    team = fresh.resolved_team_1
    allow(team).to receive(:kenshis).and_return(team.kenshis.reorder(id: :desc))

    expect(described_class.new(fresh).for_slot(1)).to eq kenshis.map(&:id)
  end

  it "ignores the current encounter's own (set) lineup" do
    roster = members(t1, 3)
    members(t2, 3)

    fresh = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    EncounterLineup.new(fresh).assign(t1, [roster[1].id, roster[0].id, roster[2].id])

    # No OTHER encounter exists, so it must fall back to roster order, not echo
    # the lineup already on this encounter.
    expect(described_class.new(fresh).for_slot(1)).to eq roster.map(&:id)
  end

  it "prefers the most recently confirmed of several previous encounters" do
    roster = members(t1, 3)
    members(t2, 3)
    t3 = create(:team, team_category: tc)
    members(t3, 3)

    older = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    EncounterLineup.new(older).assign(t1, [roster[0].id, roster[1].id, roster[2].id])
    newer = create(:encounter, team_category: tc, team_1: t1, team_2: t3)
    EncounterLineup.new(newer).assign(t1, [roster[2].id, roster[1].id, roster[0].id])

    fresh = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    expect(described_class.new(fresh).for_slot(1)).to eq [roster[2].id, roster[1].id, roster[0].id]
  end

  it "ignores an encounter of the team whose lineup was never confirmed" do
    roster = members(t1, 3)
    members(t2, 3)

    create(:encounter, team_category: tc, team_1: t1, team_2: t2)

    fresh = create(:encounter, team_category: tc, team_1: t1, team_2: t2)
    expect(described_class.new(fresh).for_slot(1)).to eq roster.map(&:id)
  end

  it "returns nothing for an unresolved bracket slot" do
    fresh = create(:encounter, team_category: tc, team_1: nil, team_2: nil, round: 2, position: 1)
    expect(described_class.new(fresh).for_slot(1)).to eq []
  end
end

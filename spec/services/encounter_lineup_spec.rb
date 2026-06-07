# frozen_string_literal: true

require "rails_helper"

RSpec.describe EncounterLineup do
  let(:tc) { create(:team_category, team_size: 3) }
  let(:t1) { create(:team, team_category: tc) }
  let(:t2) { create(:team, team_category: tc) }
  let(:encounter) { create(:encounter, team_category: tc, team_1: t1, team_2: t2) }

  def members(team, count)
    create_list(:kenshi, count, cup: tc.cup).each do |k|
      create(:participation, category: tc, team: team, kenshi: k)
    end
  end

  it "creates team_size bouts and fills the chosen side in order" do
    m = members(t1, 3)
    described_class.new(encounter).assign(t1, m.map(&:id))

    fights = encounter.team_fights.order(:position)
    expect(fights.size).to eq 3
    expect(fights.map(&:kenshi_1_id)).to eq m.map(&:id)
    expect(fights.map(&:kenshi_2_id)).to all(be_nil)
  end

  it "pairs positions once both sides are assigned" do
    a = members(t1, 3)
    b = members(t2, 3)
    described_class.new(encounter).assign(t1, a.map(&:id))
    described_class.new(encounter).assign(t2, b.map(&:id))

    fights = encounter.team_fights.order(:position)
    expect(fights.map(&:kenshi_1_id)).to eq a.map(&:id)
    expect(fights.map(&:kenshi_2_id)).to eq b.map(&:id)
  end

  it "leaves trailing positions empty (forfeit) for a short team" do
    a = members(t1, 3)
    short = members(t2, 2)
    described_class.new(encounter).assign(t1, a.map(&:id))
    described_class.new(encounter).assign(t2, short.map(&:id))

    last = encounter.team_fights.order(:position).last
    expect(last.kenshi_2_id).to be_nil
    expect(last.reload.winner_id).to eq a.last.id # forfeit win
  end

  it "selects a subset when a team has more members than team_size" do
    six = members(t1, 6) # team_size is 3
    chosen = six.first(3)
    described_class.new(encounter).assign(t1, chosen.map(&:id))
    expect(encounter.team_fights.order(:position).map(&:kenshi_1_id)).to eq chosen.map(&:id)
  end

  it "rejects a kenshi who is not on the team" do
    outsider = create(:kenshi, cup: tc.cup)
    expect {
      described_class.new(encounter).assign(t1, [outsider.id])
    }.to raise_error(EncounterLineup::InvalidLineup)
  end

  it "rejects duplicate members" do
    m = members(t1, 1).first
    expect {
      described_class.new(encounter).assign(t1, [m.id, m.id])
    }.to raise_error(EncounterLineup::InvalidLineup)
  end

  it "rejects more members than team_size" do
    m = members(t1, 4)
    expect {
      described_class.new(encounter).assign(t1, m.map(&:id))
    }.to raise_error(EncounterLineup::InvalidLineup)
  end

  it "rejects a team that is not part of the encounter" do
    other = create(:team, team_category: tc)
    expect {
      described_class.new(encounter).assign(other, [])
    }.to raise_error(EncounterLineup::InvalidLineup)
  end

  it "re-assigning a side leaves the other side's kenshi untouched" do
    a = members(t1, 3)
    b = members(t2, 3)
    replacement = members(t1, 3)
    described_class.new(encounter).assign(t1, a.map(&:id))
    described_class.new(encounter).assign(t2, b.map(&:id))
    described_class.new(encounter).assign(t1, replacement.map(&:id))

    fights = encounter.team_fights.order(:position)
    expect(fights.map(&:kenshi_1_id)).to eq replacement.map(&:id)
    expect(fights.map(&:kenshi_2_id)).to eq b.map(&:id)
  end
end

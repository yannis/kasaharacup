# frozen_string_literal: true

require "rails_helper"

RSpec.describe DaihyosenProposal do
  let(:tc) { create(:team_category, team_size: 3) }
  let(:t1) { create(:team, team_category: tc) }
  let(:t2) { create(:team, team_category: tc) }
  let(:encounter) do
    create(:encounter, team_category: tc, team_1: t1, team_2: t2,
      lineup_1_set: true, lineup_2_set: true)
  end

  # Three drawn both-present bouts -> complete and level (0-0 wins, 0-0 ippons).
  # Returns the [team_1_fighters, team_2_fighters] arrays so examples can assert
  # on the taishō without leaning on instance variables.
  def level_complete!
    a = Array.new(3) { create(:kenshi, cup: tc.cup) }
    b = Array.new(3) { create(:kenshi, cup: tc.cup) }
    (1..3).each do |position|
      create(:team_fight, encounter: encounter, position: position,
        kenshi_1: a[position - 1], kenshi_2: b[position - 1], draw: true)
    end
    [a, b]
  end

  it "creates a daihyosen of each team's last fighter, unconfirmed/unscored" do
    a, b = level_complete!

    described_class.new(encounter.reload).ensure!

    d = encounter.team_fights.find_by(daihyosen: true)
    expect(d).to be_present
    expect(d.position).to eq tc.team_size + 1
    expect(d.kenshi_1_id).to eq a.last.id
    expect(d.kenshi_2_id).to eq b.last.id
    expect(d.winner_id).to be_nil
  end

  it "is idempotent (no duplicate on a second call)" do
    level_complete!
    described_class.new(encounter.reload).ensure!
    described_class.new(encounter.reload).ensure!
    expect(encounter.team_fights.where(daihyosen: true).count).to eq 1
  end

  it "picks the last non-blank position as taisho (skips a trailing void)" do
    a = Array.new(2) { create(:kenshi, cup: tc.cup) }
    b = Array.new(2) { create(:kenshi, cup: tc.cup) }
    create(:team_fight, encounter: encounter, position: 1, kenshi_1: a[0], kenshi_2: b[0], draw: true)
    create(:team_fight, encounter: encounter, position: 2, kenshi_1: a[1], kenshi_2: b[1], draw: true)
    create(:team_fight, encounter: encounter, position: 3, kenshi_1: nil, kenshi_2: nil) # void both sides

    described_class.new(encounter.reload).ensure!

    d = encounter.team_fights.find_by(daihyosen: true)
    expect(d.kenshi_1_id).to eq a[1].id # position 2, not the void position 3
    expect(d.kenshi_2_id).to eq b[1].id
  end

  it "does nothing for a pool encounter" do
    encounter.update!(pool_number: 1)
    level_complete!
    described_class.new(encounter.reload).ensure!
    expect(encounter.team_fights.where(daihyosen: true)).to be_empty
  end

  it "does nothing while the encounter is incomplete" do
    a = Array.new(3) { create(:kenshi, cup: tc.cup) }
    b = Array.new(3) { create(:kenshi, cup: tc.cup) }
    (1..3).each do |position|
      create(:team_fight, encounter: encounter, position: position,
        kenshi_1: a[position - 1], kenshi_2: b[position - 1]) # unresolved
    end
    described_class.new(encounter.reload).ensure!
    expect(encounter.team_fights.where(daihyosen: true)).to be_empty
  end
end

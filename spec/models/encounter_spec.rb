# frozen_string_literal: true

require "rails_helper"

RSpec.describe Encounter do
  let(:tc) { create(:team_category) }

  it "is valid with two distinct teams of the category" do
    encounter = build(:encounter, team_category: tc,
      team_1: create(:team, team_category: tc), team_2: create(:team, team_category: tc))
    expect(encounter).to be_valid
  end

  it "rejects the same team on both sides" do
    team = create(:team, team_category: tc)
    encounter = build(:encounter, team_category: tc, team_1: team, team_2: team)
    expect(encounter).not_to be_valid
  end

  it "rejects a team from another category" do
    foreign = create(:team, team_category: create(:team_category))
    encounter = build(:encounter, team_category: tc,
      team_1: create(:team, team_category: tc), team_2: foreign)
    expect(encounter).not_to be_valid
  end

  describe "#recompute_winner!" do
    let(:t1) { create(:team, team_category: tc) }
    let(:t2) { create(:team, team_category: tc) }
    let(:encounter) { create(:encounter, team_category: tc, team_1: t1, team_2: t2) }

    it "persists the winning team derived from its bouts" do
      a = create(:kenshi, cup: tc.cup)
      b = create(:kenshi, cup: tc.cup)
      tf = create(:team_fight, encounter: encounter, kenshi_1: a, kenshi_2: b)
      create(:fight_point, scorable: tf, fighter_side: "fighter_1", kind: "men")

      expect(encounter.reload.winner).to eq t1 # set via TeamFight after_update_commit
    end
  end
end

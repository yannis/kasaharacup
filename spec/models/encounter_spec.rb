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

  describe "pool standings recompute" do
    let(:pool_tc) { create(:team_category, team_size: 3, pool_size: 3) }
    let(:t1) { create(:team, team_category: pool_tc, pool_number: 1, pool_position: 1) }
    let(:t2) { create(:team, team_category: pool_tc, pool_number: 1, pool_position: 2) }

    it "persists pool_rank for the pool's teams when a pool encounter completes" do
      encounter = create(:encounter, team_category: pool_tc, pool_number: 1, team_1: t1, team_2: t2)
      # Build the bouts directly (no EncounterLineup membership setup needed here).
      fights = (1..3).map do |pos|
        encounter.team_fights.create!(position: pos,
          kenshi_1: create(:kenshi, cup: pool_tc.cup), kenshi_2: create(:kenshi, cup: pool_tc.cup))
      end
      encounter.update!(lineup_1_set: true, lineup_2_set: true)
      # t1 wins two bouts, the third is a hikiwake -> t1 wins the encounter
      create(:fight_point, scorable: fights[0], fighter_side: "fighter_1", kind: "men")
      create(:fight_point, scorable: fights[1], fighter_side: "fighter_1", kind: "men")
      fights[2].update!(draw: true) # draw change fires the post-commit recompute chain

      expect(t1.reload.pool_rank).to eq 1
      expect(t2.reload.pool_rank).to eq 2
    end
  end
end

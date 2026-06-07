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
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe EncounterResult do
  let(:tc) { create(:team_category, team_size: 3) }
  let(:t1) { create(:team, team_category: tc) }
  let(:t2) { create(:team, team_category: tc) }
  let(:encounter) { create(:encounter, team_category: tc, team_1: t1, team_2: t2) }

  # Build a regular fight at the next position; winner_side: 1, 2, or nil (draw).
  def bout(winner_side, ippons_1: 0, ippons_2: 0, daihyosen: false)
    a = create(:kenshi, cup: tc.cup)
    b = create(:kenshi, cup: tc.cup)
    tf = create(:team_fight, encounter: encounter, kenshi_1: a, kenshi_2: b, daihyosen: daihyosen)
    ippons_1.times { create(:fight_point, scorable: tf, fighter_side: "fighter_1", kind: "men") }
    ippons_2.times { create(:fight_point, scorable: tf, fighter_side: "fighter_2", kind: "men") }
    tf.reload
  end

  it "wins on the higher number of individual winners" do
    bout(1, ippons_1: 1)
    bout(2, ippons_2: 1)
    bout(1, ippons_1: 1)
    expect(described_class.new(encounter.reload).winner).to eq t1
  end

  it "breaks a 1-1 wins tie on total points" do
    bout(1, ippons_1: 2) # t1: 1 win, 2 ippons
    bout(2, ippons_2: 1) # t2: 1 win, 1 ippon
    bout(nil, ippons_1: 1, ippons_2: 1) # draw, +1 ippon each
    # wins 1-1; ippons 3-2 -> t1
    expect(described_class.new(encounter.reload).winner).to eq t1
  end

  it "is unresolved when wins and ippons tie and there is no daihyosen" do
    bout(1, ippons_1: 1)
    bout(2, ippons_2: 1)
    bout(nil)
    expect(described_class.new(encounter.reload).winner).to be_nil
  end

  it "resolves a full tie via the daihyosen winner's team" do
    bout(1, ippons_1: 1)
    bout(2, ippons_2: 1)
    bout(nil)
    bout(2, ippons_2: 1, daihyosen: true) # representative of team 2 wins
    expect(described_class.new(encounter.reload).winner).to eq t2
  end
end

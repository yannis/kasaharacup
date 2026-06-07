# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamFight do
  let(:tc) { create(:team_category, team_size: 5) }
  let(:encounter) { create(:encounter, team_category: tc) }
  let(:k1) { create(:kenshi, cup: tc.cup) }
  let(:k2) { create(:kenshi, cup: tc.cup) }

  def fight(daihyosen: false, k1_present: true, k2_present: true)
    create(:team_fight, encounter: encounter, daihyosen: daihyosen,
      kenshi_1: (k1 if k1_present), kenshi_2: (k2 if k2_present))
  end

  def point(team_fight, side, kind: "men")
    create(:fight_point, scorable: team_fight, fighter_side: side, kind: kind)
  end

  it "awards the win to the side with more points" do
    tf = fight
    point(tf, "fighter_1")
    expect(tf.reload).to have_attributes(winner_id: k1.id, draw: false)
  end

  it "declares hikiwake at 1-1" do
    tf = fight
    point(tf, "fighter_1")
    point(tf, "fighter_2")
    expect(tf.reload).to have_attributes(winner_id: nil, draw: true)
  end

  it "wins immediately at two points (sanbon-shobu)" do
    tf = fight
    point(tf, "fighter_1", kind: "men")
    point(tf, "fighter_1", kind: "kote")
    expect(tf.reload).to have_attributes(winner_id: k1.id, draw: false)
  end

  it "treats a one-sided lineup as a forfeit win for the present side" do
    tf = fight(k2_present: false)
    tf.resolve_lineup! # forfeit resolution is triggered by EncounterLineup, not on create
    expect(tf.reload).to have_attributes(winner_id: k1.id, draw: false)
    expect(tf.individual_points(1)).to eq 2
    expect(tf.individual_points(2)).to eq 0
  end

  it "leaves a daihyosen undecided at 0-0 (no hikiwake)" do
    tf = fight(daihyosen: true)
    tf.recompute_outcome_from_points!
    expect(tf.reload).to have_attributes(winner_id: nil, draw: false)
  end

  it "decides a daihyosen on the first point (ippon-shobu)" do
    tf = fight(daihyosen: true)
    point(tf, "fighter_2")
    expect(tf.reload).to have_attributes(winner_id: k2.id, draw: false)
  end
end

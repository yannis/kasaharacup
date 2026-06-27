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

  it "resets a both-present bout to pending (not hikiwake) when its last point is removed" do
    tf = fight
    p = point(tf, "fighter_1")
    expect(tf.reload).to have_attributes(winner_id: k1.id, draw: false)

    p.destroy!
    # Back to 0-0 with no points: the bout is unscored/pending, NOT an automatic
    # hikiwake. A genuine 0-0 draw is the admin's explicit call.
    expect(tf.reload).to have_attributes(winner_id: nil, draw: false)
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

  describe "#void?" do
    it "is true only when both kenshi slots are empty" do
      both_empty = create(:team_fight, encounter: encounter, kenshi_1: nil, kenshi_2: nil)
      one_side = create(:team_fight, encounter: encounter, kenshi_1: k1, kenshi_2: nil)
      both = create(:team_fight, encounter: encounter, kenshi_1: k1, kenshi_2: k2)

      expect(both_empty.void?).to be true
      expect(one_side.void?).to be false
      expect(both.void?).to be false
    end
  end

  describe "#hikiwake_eligible?" do
    let(:tc) { create(:team_category, team_size: 3) }
    let(:t1) { create(:team, team_category: tc) }
    let(:t2) { create(:team, team_category: tc) }
    let(:encounter) do
      create(:encounter, team_category: tc, team_1: t1, team_2: t2,
        lineup_1_set: true, lineup_2_set: true)
    end
    let(:a) { create(:kenshi, cup: tc.cup) }
    let(:b) { create(:kenshi, cup: tc.cup) }

    it "is true for a confirmed, both-present, unscored, winner-less regular bout" do
      tf = create(:team_fight, encounter: encounter, kenshi_1: a, kenshi_2: b)
      expect(tf.hikiwake_eligible?).to be true
    end

    it "is false when a lineup is not confirmed" do
      encounter.update!(lineup_2_set: false)
      tf = create(:team_fight, encounter: encounter, kenshi_1: a, kenshi_2: b)
      expect(tf.hikiwake_eligible?).to be false
    end

    it "is false for a forfeit (one side empty)" do
      tf = create(:team_fight, encounter: encounter, kenshi_1: a, kenshi_2: nil)
      expect(tf.hikiwake_eligible?).to be false
    end

    it "is false once the bout has points" do
      tf = create(:team_fight, encounter: encounter, kenshi_1: a, kenshi_2: b)
      create(:fight_point, scorable: tf, fighter_side: "fighter_1", kind: "men")
      expect(tf.reload.hikiwake_eligible?).to be false
    end

    it "is false for a winner-bearing bout" do
      tf = create(:team_fight, encounter: encounter, kenshi_1: a, kenshi_2: b, winner: a)
      expect(tf.hikiwake_eligible?).to be false
    end

    it "is false for the daihyosen bout" do
      tf = create(:team_fight, encounter: encounter, kenshi_1: a, kenshi_2: b,
        daihyosen: true, position: tc.team_size + 1)
      expect(tf.hikiwake_eligible?).to be false
    end
  end
end

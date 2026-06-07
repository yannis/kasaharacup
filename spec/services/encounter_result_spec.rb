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

  describe "completeness and draws" do
    let(:tc) { create(:team_category, team_size: 3) }

    def lineup(slot, *members)
      members.each_with_index do |m, i|
        tf = encounter.team_fights.find_or_create_by!(position: i + 1)
        tf.update!("kenshi_#{slot}_id": m&.id)
      end
      encounter.update!("lineup_#{slot}_set": true)
    end

    it "is not complete until both lineups are in" do
      a = Array.new(3) { create(:kenshi, cup: tc.cup) }
      lineup(1, *a)
      expect(described_class.new(encounter.reload).complete?).to be false
    end

    it "is not complete while a non-void bout is unresolved" do
      a = Array.new(3) { create(:kenshi, cup: tc.cup) }
      b = Array.new(3) { create(:kenshi, cup: tc.cup) }
      lineup(1, *a)
      lineup(2, *b)
      expect(described_class.new(encounter.reload).complete?).to be false # no points scored yet
    end

    it "treats a finished tied encounter as a draw for both teams" do
      a = Array.new(3) { create(:kenshi, cup: tc.cup) }
      b = Array.new(3) { create(:kenshi, cup: tc.cup) }
      lineup(1, *a)
      lineup(2, *b)
      fights = encounter.team_fights.order(:position).to_a
      create(:fight_point, scorable: fights[0], fighter_side: "fighter_1", kind: "men") # t1 win
      create(:fight_point, scorable: fights[1], fighter_side: "fighter_2", kind: "men") # t2 win
      fights[2].update!(draw: true) # hikiwake
      res = described_class.new(encounter.reload)

      expect(res.complete?).to be true
      expect(res.outcome_for(t1)).to eq :draw
      expect(res.outcome_for(t2)).to eq :draw
      expect(res.draws).to eq 1
      expect(res.team_1_losses).to eq res.team_2_wins
    end

    it "is complete with void trailing bouts (two short teams)" do
      a = Array.new(2) { create(:kenshi, cup: tc.cup) }
      b = Array.new(2) { create(:kenshi, cup: tc.cup) }
      lineup(1, a[0], a[1], nil)
      lineup(2, b[0], b[1], nil)
      fights = encounter.team_fights.order(:position).to_a
      create(:fight_point, scorable: fights[0], fighter_side: "fighter_1", kind: "men")
      fights[1].update!(draw: true) # resolve the second real fight
      res = described_class.new(encounter.reload)

      expect(res.complete?).to be true # the position-3 void bout doesn't block completeness
      expect(res.team_1_wins).to eq 1  # void bout excluded from the win count
      expect(res.team_2_wins).to eq 0
      expect(res.draws).to eq 1
      expect(res.outcome_for(t1)).to eq :win
    end
  end
end

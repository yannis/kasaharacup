# frozen_string_literal: true

require "rails_helper"

RSpec.describe BracketDisplayNumbering do
  let(:category) { create(:individual_category) }

  describe ".for" do
    # Reproduces the worked example: the subtree under one round-4 match, with a
    # single contested round-1 fight and the rest of round 1 being byes.
    #
    #   r1: F1(bye) F2(real) F3(bye) F4(bye) F5(bye) F6(bye) F7(bye) F8(bye)
    #   r2: F17(F1,F2) F18(F3,F4) F19(F5,F6) F20(F7,F8)
    #   r3: F25(F17,F18) F26(F19,F20)
    #   r4: F29(F25,F26)
    #
    # Post-order, skipping byes, yields:
    #   F2=1 F17=2 F18=3 F25=4 F19=5 F20=6 F26=7 F29=8
    it "numbers real matches post-order to the highest round possible, skipping byes" do
      bye1 = bye_fight(number: 1, position: 1)
      real2 = real_fight(number: 2, position: 2)
      bye3 = bye_fight(number: 3, position: 3)
      bye4 = bye_fight(number: 4, position: 4)
      bye5 = bye_fight(number: 5, position: 5)
      bye6 = bye_fight(number: 6, position: 6)
      bye7 = bye_fight(number: 7, position: 7)
      bye8 = bye_fight(number: 8, position: 8)

      f17 = forecast_fight(number: 17, round: 2, position: 1, parents: [bye1, real2])
      f18 = forecast_fight(number: 18, round: 2, position: 2, parents: [bye3, bye4])
      f19 = forecast_fight(number: 19, round: 2, position: 3, parents: [bye5, bye6])
      f20 = forecast_fight(number: 20, round: 2, position: 4, parents: [bye7, bye8])

      f25 = forecast_fight(number: 25, round: 3, position: 1, parents: [f17, f18])
      f26 = forecast_fight(number: 26, round: 3, position: 2, parents: [f19, f20])

      f29 = forecast_fight(number: 29, round: 4, position: 1, parents: [f25, f26])

      numbers = described_class.for(loaded_fights)

      expect(numbers.values_at(real2.id, f17.id, f18.id, f25.id, f19.id, f20.id, f26.id, f29.id))
        .to eq([1, 2, 3, 4, 5, 6, 7, 8])
    end

    it "does not assign a number to bye fights" do
      bye = bye_fight(number: 1, position: 1)
      real = real_fight(number: 2, position: 2)
      forecast_fight(number: 3, round: 2, position: 1, parents: [bye, real])

      numbers = described_class.for(loaded_fights)

      expect(numbers).not_to have_key(bye.id)
    end

    it "returns an empty hash when there are no fights" do
      expect(described_class.for([])).to eq({})
    end
  end

  describe "with team encounters" do
    let(:tc) { create(:team_category) }

    def team = create(:team, team_category: tc)

    it "numbers encounters leaf-first, skipping byes" do
      r1a = create(:encounter, team_category: tc, team_1: team, team_2: team, round: 1, position: 1, number: 1)
      r1b = create(:encounter, team_category: tc, team_1: team, team_2: nil, round: 1, position: 2, number: 2)
      final = create(:encounter, team_category: tc, round: 2, position: 1, number: 3,
        parent_encounter_1: r1a, parent_encounter_2: r1b)

      list = [r1a, r1b, final]
      Encounter.preload_parents(list)
      numbers = described_class.for(list)

      expect(numbers[r1b.id]).to be_nil
      expect(numbers[r1a.id]).to eq 1
      expect(numbers[final.id]).to eq 2
    end
  end

  def loaded_fights
    fights = category.bracket_fights.bracket_order.to_a
    Fight.preload_parents(fights)
    fights
  end

  def real_fight(number:, position:, round: 1)
    create(:fight, individual_category: category, number: number, round: round, position: position)
  end

  def bye_fight(number:, position:, round: 1)
    kenshi = create(:kenshi, cup: category.cup,
      participations: [build(:participation, category: category)])
    create(:fight, individual_category: category, number: number, round: round,
      position: position, fighter_1: kenshi, fighter_2: nil)
  end

  def forecast_fight(number:, round:, position:, parents:)
    create(:fight, individual_category: category, number: number, round: round,
      position: position, fighter_1: nil, fighter_2: nil,
      parent_fight_1: parents[0], parent_fight_2: parents[1])
  end
end

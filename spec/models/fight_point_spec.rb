# frozen_string_literal: true

require "rails_helper"

RSpec.describe FightPoint do
  describe "Associations and enums" do
    let(:fight_point) { build(:fight_point) }

    it do
      expect(fight_point).to belong_to(:scorable)

      side_values = {fighter_1: "fighter_1", fighter_2: "fighter_2"}
      expect(fight_point)
        .to define_enum_for(:fighter_side)
        .with_values(side_values)
        .backed_by_column_of_type(:string)

      kind_values = {
        men: "men", kote: "kote", do: "do",
        tsuki: "tsuki", ippon: "ippon", hansoku: "hansoku"
      }
      expect(fight_point)
        .to define_enum_for(:kind)
        .with_values(kind_values)
        .backed_by_column_of_type(:string)
    end
  end

  describe "position auto-assignment" do
    let(:fight) { create(:fight) }

    it "starts at 1 for the first point on a fight" do
      point = create(:fight_point, scorable: fight)

      expect(point.position).to eq 1
    end

    it "increments per point across both sides to preserve the match timeline" do
      first = create(:fight_point, scorable: fight, fighter_side: "fighter_1", kind: "men")
      second = create(:fight_point, scorable: fight, fighter_side: "fighter_2", kind: "kote")
      third = create(:fight_point, scorable: fight, fighter_side: "fighter_1", kind: "hansoku")

      expect([first.position, second.position, third.position]).to eq [1, 2, 3]
    end

    it "respects an explicitly supplied position" do
      point = create(:fight_point, scorable: fight, position: 42)

      expect(point.position).to eq 42
    end
  end

  describe "ippon limit per side" do
    let(:fight) { create(:fight) }

    it "rejects a third non-hansoku point on the same side" do
      create(:fight_point, scorable: fight, fighter_side: "fighter_1", kind: "men")
      create(:fight_point, scorable: fight, fighter_side: "fighter_1", kind: "kote")

      third = build(:fight_point, scorable: fight, fighter_side: "fighter_1", kind: "ippon")

      expect(third).not_to be_valid
      expect(third.errors[:base]).to include("Fighter already has 2 non-hansoku points")
    end

    it "does not count hansoku toward the limit" do
      create(:fight_point, scorable: fight, fighter_side: "fighter_1", kind: "hansoku")
      create(:fight_point, scorable: fight, fighter_side: "fighter_1", kind: "hansoku")
      create(:fight_point, scorable: fight, fighter_side: "fighter_1", kind: "hansoku")

      expect(described_class.where(scorable: fight, fighter_side: "fighter_1").count).to eq 3
    end

    it "tracks the limit independently for each side" do
      create(:fight_point, scorable: fight, fighter_side: "fighter_1", kind: "men")
      create(:fight_point, scorable: fight, fighter_side: "fighter_1", kind: "kote")

      opponent_point = build(:fight_point, scorable: fight, fighter_side: "fighter_2", kind: "do")

      expect(opponent_point).to be_valid
    end
  end

  describe "touches parent fight" do
    let(:cup) { create(:cup) }
    let(:category) { create(:individual_category, cup: cup) }
    let(:k1) { create(:kenshi, cup: cup, participations: [build(:participation, category: category)]) }
    let(:k2) { create(:kenshi, cup: cup, participations: [build(:participation, category: category)]) }
    let(:fight) {
      create(:fight, :pool_fight, individual_category: category, pool_number: 1,
        fighter_1: k1, fighter_2: k2)
    }

    it "touches the fight when a point is created" do
      original = fight.updated_at
      travel(1.second) do
        create(:fight_point, scorable: fight, fighter_side: "fighter_1", kind: "men")
      end
      expect(fight.reload.updated_at).to be > original
    end

    it "touches the fight when a point is destroyed" do
      point = create(:fight_point, scorable: fight, fighter_side: "fighter_1", kind: "men")
      original = fight.reload.updated_at
      travel(1.second) do
        point.destroy!
      end
      expect(fight.reload.updated_at).to be > original
    end
  end

  describe "#code" do
    {
      "men" => "M",
      "kote" => "K",
      "do" => "D",
      "tsuki" => "T",
      "ippon" => "I",
      "hansoku" => "△"
    }.each do |kind, code|
      it "returns #{code.inspect} for #{kind}" do
        expect(build(:fight_point, kind: kind).code).to eq code
      end
    end
  end
end

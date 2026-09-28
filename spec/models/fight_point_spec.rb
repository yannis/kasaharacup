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
        tsuki: "tsuki", ippon: "ippon", hansoku: "hansoku",
        hansoku_ippon: "hansoku_ippon"
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

  describe "H point (hansoku ippon)" do
    let(:fight) { create(:fight) }

    def hansoku(side = "fighter_1")
      create(:fight_point, scorable: fight, fighter_side: side, kind: "hansoku")
    end

    def h_points(side = "fighter_2")
      described_class.where(scorable: fight, fighter_side: side, kind: "hansoku_ippon")
    end

    it "awards nothing for a single hansoku" do
      hansoku

      expect(h_points).to be_empty
    end

    it "awards the opponent an H for the second hansoku, right after it" do
      hansoku
      second = hansoku

      expect(h_points.map(&:position)).to eq [second.position + 1]
      expect(h_points("fighter_1")).to be_empty
    end

    it "awards a second H for the fourth hansoku" do
      4.times { hansoku }

      expect(h_points.count).to eq 2
    end

    it "makes the H win the bout for the opponent" do
      2.times { hansoku }

      expect(fight.reload.winner).to eq fight.fighter_2
    end

    it "withdraws the H when one of the pair of hansoku is removed" do
      hansoku
      second = hansoku

      second.destroy!

      expect(h_points).to be_empty
      expect(fight.reload.winner).to be_nil
    end

    it "keeps the H while two hansoku remain" do
      3.times { hansoku }

      described_class.where(scorable: fight, kind: "hansoku").last.destroy!

      expect(h_points.count).to eq 1
    end

    it "counts the H toward the opponent's two-point limit" do
      create(:fight_point, scorable: fight, fighter_side: "fighter_2", kind: "men")
      2.times { hansoku }

      third = build(:fight_point, scorable: fight, fighter_side: "fighter_2", kind: "kote")

      expect(third).not_to be_valid
    end

    it "refuses the hansoku whose H the opponent has no room for" do
      create(:fight_point, scorable: fight, fighter_side: "fighter_2", kind: "men")
      create(:fight_point, scorable: fight, fighter_side: "fighter_2", kind: "kote")
      hansoku

      expect { hansoku }.to raise_error(ActiveRecord::RecordInvalid)
      expect(described_class.where(scorable: fight, kind: "hansoku").count).to eq 1
    end

    it "cannot be entered without the opponent's pair of hansoku" do
      hansoku

      point = build(:fight_point, scorable: fight, fighter_side: "fighter_2", kind: "hansoku_ippon")

      expect(point).not_to be_valid
      expect(point.errors[:base]).to include("An H point needs two hansoku on the opponent")
    end

    it "goes with its fight when the fight is destroyed" do
      2.times { hansoku }

      expect { fight.destroy! }.to change(described_class, :count).by(-3)
    end

    it "is awarded on team bouts too" do
      team_fight = create(:team_fight)
      2.times { create(:fight_point, scorable: team_fight, fighter_side: "fighter_2", kind: "hansoku") }

      expect(team_fight.points_for(1).map(&:kind)).to eq ["hansoku_ippon"]
    end
  end

  describe "ENTERABLE_CODES" do
    it "offers every kind but the H, which only hansoku award" do
      expect(described_class::ENTERABLE_CODES.keys).to eq %w[men kote do tsuki ippon hansoku]
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
      "hansoku" => "△",
      "hansoku_ippon" => "H"
    }.each do |kind, code|
      it "returns #{code.inspect} for #{kind}" do
        expect(build(:fight_point, kind: kind).code).to eq code
      end
    end
  end
end

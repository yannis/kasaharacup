# frozen_string_literal: true

require "rails_helper"

RSpec.describe BracketWaitingEntries do
  let(:cup) { create(:cup) }

  context "on a pooled team category" do
    let(:category) { create(:team_category, cup: cup, pool_size: 3, out_of_pool: 2) }

    before do
      (1..2).each do |pool|
        (1..2).each { |rank| create(:team, team_category: category, pool_number: pool, pool_rank: rank) }
      end
      TeamCategoryBracketBuilder.new(category).call
    end

    def round_one = category.bracket_encounters.where(round: 1).order(:position).to_a

    it "is empty after a fresh draw" do
      expect(described_class.for(category)).to be_empty
    end

    it "holds what was pulled out of the tree" do
      unit = round_one.first
      pulled = unit.slot_entry(1)
      unit.clear_slot(1)

      expect(described_class.for(category).map(&:key)).to eq [pulled.key]
    end

    # BOTH qualifiers, though only one team is in the new pool: out_of_pool is
    # 2, so the category expects 3.1 and 3.2, and 3.2 is a descriptor with
    # nobody behind it yet. That is exactly the slot the builder's #slot_specs
    # would create for it, so the waiting area and a rebuild agree.
    it "picks up a pool created after the draw" do
      create(:team, team_category: category, pool_number: 3, pool_rank: 1)

      expect(described_class.for(category).map(&:key)).to eq ["3.1", "3.2"]
    end

    it "resolves the competitor behind a waiting descriptor" do
      unit = round_one.first
      team = unit.slot_entry(1).competitor
      unit.clear_slot(1)

      expect(described_class.for(category).first.competitor).to eq team
    end

    it "empties again after a force rebuild" do
      round_one.first.clear_slot(1)
      expect(described_class.for(category)).not_to be_empty

      TeamCategoryBracketBuilder.new(category, rebuild_started: true).call

      expect(described_class.for(category.reload)).to be_empty
    end
  end

  context "on a pool-less team category" do
    let(:category) { create(:team_category, cup: cup, pool_size: nil) }

    before do
      create_list(:team, 4, team_category: category)
      TeamCategoryBracketBuilder.new(category, random: Random.new(1)).call
    end

    it "is empty after a fresh draw" do
      expect(described_class.for(category)).to be_empty
    end

    it "holds a team pulled out of the tree, keyed by id" do
      unit = category.bracket_encounters.where(round: 1).order(:position).first
      team = unit.team_1
      unit.clear_slot(1)

      expect(described_class.for(category).map(&:key)).to eq ["team-#{team.id}"]
    end
  end

  # The case EncounterTeamSwap.ineligibility_reason documents: lowering
  # pool_size to 1 makes a category bracket_only? while its round-1 slots still
  # carry the previous draw's pool descriptors. Branch on the flag and the
  # expected set is teams-by-id while the placed set is descriptors, so nothing
  # subtracts and every team shows as waiting.
  context "on a bracket-only category whose slots still carry descriptors" do
    let(:category) { create(:team_category, cup: cup, pool_size: 3, out_of_pool: 2) }

    before do
      (1..2).each do |pool|
        (1..2).each { |rank| create(:team, team_category: category, pool_number: pool, pool_rank: rank) }
      end
      TeamCategoryBracketBuilder.new(category).call
      category.update!(pool_size: 1)
    end

    it "reads the placed set off what the slots actually carry" do
      expect(category.reload).to be_bracket_only
      expect(described_class.for(category)).to be_empty
    end
  end

  context "on an individual category" do
    let(:category) { create(:individual_category, cup: cup, pool_size: 3, out_of_pool: 2) }

    before do
      (1..2).each do |pool|
        (1..2).each do |rank|
          create(:participation, category: category, pool_number: pool, pool_position: rank, pool_rank: rank)
        end
      end
      IndividualCategoryBracketBuilder.new(category).call
    end

    it "is empty after a fresh draw" do
      expect(described_class.for(category)).to be_empty
    end

    it "holds a kenshi pulled out of the tree" do
      fight = category.bracket_fights.where(round: 1).order(:position).first
      pulled = fight.slot_entry(1)
      fight.clear_slot(1)

      expect(described_class.for(category).map(&:key)).to eq [pulled.key]
    end
  end
end

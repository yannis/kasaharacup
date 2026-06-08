# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamCategoryBracketBuilder do
  let(:cup) { create(:cup) }
  let(:category) { create(:team_category, cup: cup, pool_size: 3, out_of_pool: 2) }

  def ranked_team(pool_number:, pool_rank:)
    create(:team, team_category: category, pool_number: pool_number, pool_rank: pool_rank)
  end

  context "with 2 pools × 2 ranks" do
    let!(:t1_1) { ranked_team(pool_number: 1, pool_rank: 1) }
    let!(:t1_2) { ranked_team(pool_number: 1, pool_rank: 2) }
    let!(:t2_1) { ranked_team(pool_number: 2, pool_rank: 1) }
    let!(:t2_2) { ranked_team(pool_number: 2, pool_rank: 2) }

    it "creates a 4-team bracket: 2 first-round encounters + 1 final" do
      encounters = described_class.new(category).call

      expect(encounters.count { |e| e.round == 1 }).to eq 2
      expect(encounters.count { |e| e.round == 2 }).to eq 1
    end

    it "splits each pool's rank-1 and rank-2 across the two first-round encounters" do
      described_class.new(category).call
      round_one = category.bracket_encounters.where(round: 1).order(:position)

      round_one.each do |enc|
        pools = [enc.team_1.pool_number, enc.team_2.pool_number]
        expect(pools.uniq.size).to eq 2 # cross-pool
      end
    end

    it "wires the final to both first-round encounters" do
      described_class.new(category).call
      round_one = category.bracket_encounters.where(round: 1).order(:position).to_a
      final = category.bracket_encounters.find_by(round: 2)

      expect(final.parent_encounter_1).to eq round_one[0]
      expect(final.parent_encounter_2).to eq round_one[1]
    end
  end

  context "with a bye (3 teams)" do
    let(:category) { create(:team_category, cup: cup, pool_size: 1, out_of_pool: 1) }
    let!(:t1_1) { ranked_team(pool_number: 1, pool_rank: 1) }
    let!(:t2_1) { ranked_team(pool_number: 2, pool_rank: 1) }
    let!(:t3_1) { ranked_team(pool_number: 3, pool_rank: 1) }

    it "seeds the bye team into its round-2 child slot at build time" do
      described_class.new(category).call
      final = category.bracket_encounters.find_by(round: 2)
      bye = category.bracket_encounters.where(round: 1).detect(&:bye?)

      seeded = [final.team_1_id, final.team_2_id]
      expect(seeded).to include(bye.bye_team.id)
    end
  end

  context "idempotency and re-resolve" do
    let(:category) { create(:team_category, cup: cup, pool_size: 1, out_of_pool: 1) }
    let!(:t1_1) { ranked_team(pool_number: 1, pool_rank: 1) }
    let!(:t2_1) { ranked_team(pool_number: 2, pool_rank: 1) }

    it "does not duplicate encounters on a second call" do
      described_class.new(category).call
      expect { described_class.new(category).call }
        .not_to change { category.bracket_encounters.count }
    end

    it "re-resolves a first-round slot through assign_team_to_slot when ranks change" do
      described_class.new(category).call
      enc = category.bracket_encounters.find_by(round: 1, team_1_pool_number: 1)
      replacement = ranked_team(pool_number: 1, pool_rank: 1)
      t1_1.update!(pool_rank: nil)

      described_class.new(category).call

      expect(enc.reload.team_1_id).to eq replacement.id
    end
  end
end

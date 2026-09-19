# frozen_string_literal: true

require "rails_helper"

# Both includers are exercised against the same contract, because SeedOrderMove
# drives them through it and a divergence would only show up as the panel and
# the draw disagreeing about the order.
RSpec.describe Seedable do
  let(:cup) { create(:cup) }

  shared_examples "a seedable record" do
    it "reports whether it is seeded" do
      expect(seedable(seed: 2)).to be_seeded
      expect(seedable).not_to be_seeded
    end

    it "rejects a seed that is not a positive integer" do
      record = seedable
      record.seed = 0
      expect(record).not_to be_valid

      record.seed = -1
      expect(record).not_to be_valid

      record.seed = 1
      expect(record).to be_valid
    end

    it "allows a nil seed" do
      expect(seedable(seed: nil)).to be_valid
    end

    it "scopes to the seeded, in seed order" do
      third = seedable(seed: 3)
      first = seedable(seed: 1)
      seedable

      expect(described_class.seeded.to_a).to eq [first, third]
    end

    # The tie-break that keeps the panel, the poolers and BracketOnlySeeder
    # agreeing while a duplicate exists — which it can, between a destroy in
    # ActiveAdmin and the next renumbering.
    it "breaks a duplicate seed on id" do
      first = seedable(seed: 1)
      second = seedable(seed: 1)

      expect(described_class.seeded.to_a).to eq [first, second].sort_by(&:id)
    end

    it "orders records already in memory the same way" do
      third = seedable(seed: 3)
      first = seedable(seed: 1)
      spare = seedable

      expect(described_class.in_seed_order([spare, third, first])).to eq [first, third]
    end

    it "points SeedOrderMove at the category that owns the order" do
      record = seedable(seed: 1)

      expect(record.seed_group).to eq group
      expect(record.seed_siblings.to_a).to include(record)
    end
  end

  describe Participation do
    let(:group) { create(:individual_category, cup: cup, pool_size: 3) }

    def seedable(seed: nil)
      create(:participation, category: group, kenshi: create(:kenshi, cup: cup), seed: seed)
    end

    it_behaves_like "a seedable record"
  end

  describe Team do
    let(:group) { create(:team_category, cup: cup, pool_size: 3) }
    let(:sequence) { (1..).each }

    def seedable(seed: nil)
      create(:team, team_category: group, name: "Team #{sequence.next}", seed: seed)
    end

    it_behaves_like "a seedable record"
  end
end

# frozen_string_literal: true

require "rails_helper"

RSpec.describe CategoryPoolSlots do
  let(:cup) { create(:cup) }

  context "on a team category" do
    let(:category) { create(:team_category, cup: cup, pool_size: 3, out_of_pool: 2) }
    let!(:winner) { create(:team, team_category: category, pool_number: 1, pool_rank: 1) }
    let!(:runner_up) { create(:team, team_category: category, pool_number: 1, pool_rank: 2) }
    let!(:unpooled) { create(:team, team_category: category) }

    it "indexes the pooled competitors by pool position" do
      slots = described_class.new(category)

      expect(slots.competitor_at(1, 1)).to eq winner
      expect(slots.competitor_at(1, 2)).to eq runner_up
      expect(slots.competitor_at(2, 1)).to be_nil
    end

    it "lists the pool numbers in ascending order" do
      create(:team, team_category: category, pool_number: 3, pool_rank: 1)

      expect(described_class.new(category).pool_numbers).to eq [1, 3]
    end

    # The builders create a slot per (pool, rank) from this BEFORE anyone is
    # ranked — descriptors first, payloads when the standings land. Deriving it
    # from the ranked lookup instead reported no pools at all and built no
    # bracket.
    it "lists a pool nobody in it is ranked in yet" do
      create(:team, team_category: category, pool_number: 4)

      expect(described_class.new(category).pool_numbers).to include 4
    end

    it "ignores a competitor with no pool" do
      expect(described_class.new(category).competitors).not_to include unpooled
    end
  end

  context "on an individual category" do
    let(:category) { create(:individual_category, cup: cup, pool_size: 3, out_of_pool: 2) }
    let!(:winner) { create(:participation, category: category, pool_number: 1, pool_position: 1, pool_rank: 1) }

    # The individual builder seeds a kenshi, not a participation, so this has to
    # hand back the kenshi or the builder's slot payloads change shape.
    it "indexes kenshis by pool position" do
      expect(described_class.new(category).competitor_at(1, 1)).to eq winner.kenshi
    end
  end
end

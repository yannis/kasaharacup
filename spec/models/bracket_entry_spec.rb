# frozen_string_literal: true

require "rails_helper"

RSpec.describe BracketEntry do
  let(:cup) { create(:cup) }
  let(:category) { create(:team_category, cup: cup) }
  let(:team) { create(:team, team_category: category, name: "Kendo Club B") }

  describe ".for" do
    it "is nil when there is neither a descriptor nor a competitor" do
      expect(described_class.for(pool_number: nil, pool_rank: nil, competitor: nil)).to be_nil
    end

    it "builds an entry from a descriptor alone" do
      entry = described_class.for(pool_number: 3, pool_rank: 2, competitor: nil)

      expect(entry).to have_attributes(pool_number: 3, pool_rank: 2, competitor: nil)
    end

    it "builds an entry from a competitor alone" do
      entry = described_class.for(pool_number: nil, pool_rank: nil, competitor: team)

      expect(entry.competitor).to eq team
    end
  end

  describe "#label" do
    it "is the pool position when the entry carries a descriptor" do
      entry = described_class.for(pool_number: 3, pool_rank: 2, competitor: team)

      expect(entry.label).to eq "3.2"
    end

    it "falls back to the competitor's name with no descriptor" do
      entry = described_class.for(pool_number: nil, pool_rank: nil, competitor: team)

      expect(entry.label).to eq "Kendo Club B"
    end

    it "uses a kenshi's full name" do
      kenshi = create(:kenshi, cup: cup)
      entry = described_class.for(pool_number: nil, pool_rank: nil, competitor: kenshi)

      expect(entry.label).to eq kenshi.full_name
    end
  end

  describe "#key" do
    it "is the pool position when the entry carries a descriptor" do
      entry = described_class.for(pool_number: 3, pool_rank: 2, competitor: team)

      expect(entry.key).to eq "3.2"
    end

    # The descriptor wins even when a competitor is resolved behind it: the
    # descriptor is what the slot will re-resolve from, so it is what has to
    # survive a round trip through the client.
    it "prefers the descriptor over the competitor" do
      with_team = described_class.for(pool_number: 3, pool_rank: 2, competitor: team)
      without = described_class.for(pool_number: 3, pool_rank: 2, competitor: nil)

      expect(with_team.key).to eq without.key
    end

    it "is a typed competitor id with no descriptor" do
      entry = described_class.for(pool_number: nil, pool_rank: nil, competitor: team)

      expect(entry.key).to eq "team-#{team.id}"
    end
  end

  describe "#descriptor?" do
    it "needs both halves of the descriptor" do
      expect(described_class.for(pool_number: 3, pool_rank: nil, competitor: team))
        .not_to be_descriptor
    end
  end
end

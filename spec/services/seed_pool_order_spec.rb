# frozen_string_literal: true

require "rails_helper"

RSpec.describe SeedPoolOrder do
  # Asks BracketSeeder for the cut rather than restating it: a private copy of
  # the rule here would keep passing after the seeder's cut changed, while every
  # category was being mis-seeded.
  def top_half?(pool, count)
    BracketSeeder.low_block((1..count).to_a).include?(pool)
  end

  def halves(count)
    described_class.order(count).map { |pool| top_half?(pool, count) }
  end

  describe ".order" do
    # Pinned literally: the pooler reads this sequence, and a silent change to
    # it reseeds every individual category at once.
    it "returns the standard pool order for each pool count" do
      expect(described_class.order(1)).to eq [1]
      expect(described_class.order(2)).to eq [1, 2]
      expect(described_class.order(3)).to eq [1, 3, 2]
      expect(described_class.order(4)).to eq [1, 3, 4, 2]
      expect(described_class.order(5)).to eq [1, 4, 5, 3, 2]
      expect(described_class.order(6)).to eq [1, 4, 6, 3, 2, 5]
      expect(described_class.order(8)).to eq [1, 5, 7, 3, 4, 8, 6, 2]
    end

    it "returns no pools for an empty category" do
      expect(described_class.order(0)).to eq []
    end

    it "uses every pool exactly once" do
      (1..16).each do |count|
        expect(described_class.order(count).sort).to eq((1..count).to_a), "pool count #{count}"
      end
    end

    # The property the whole module exists to provide.
    it "sends the top two seeds to opposite halves of the tree" do
      (2..16).each do |count|
        expect(halves(count)[0]).not_to eq(halves(count)[1]), "pool count #{count}"
      end
    end

    # The standard draw: seed 3 meets seed 2 and seed 4 meets seed 1, so the
    # projected semifinals are 1 v 4 and 2 v 3 (the layout BracketPositions
    # documents), not 1 v 3 and 2 v 4.
    it "pairs seed 3 with seed 2 and seed 4 with seed 1" do
      (4..16).each do |count|
        expect(halves(count)[2]).to eq(halves(count)[1]), "pool count #{count}"
        expect(halves(count)[3]).to eq(halves(count)[0]), "pool count #{count}"
      end
    end

    # An odd count leaves the high block one pool short, and at three pools it
    # is a single pool: seed 2 takes it, so seed 3 has nowhere to go but the
    # top half. The shape of the tree, not a flaw in the ordering.
    it "puts seed 3 beside seed 1 at three pools, where the bottom half is one pool wide" do
      expect(halves(3)).to eq [true, false, true]
    end
  end
end

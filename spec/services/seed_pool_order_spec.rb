# frozen_string_literal: true

require "rails_helper"

RSpec.describe SeedPoolOrder do
  # Asks BracketSeeder for the cut rather than restating it: a private copy of
  # the rule here would keep passing after the seeder's cut changed, while every
  # category was being mis-seeded.
  def top_half?(pool, count)
    BracketSeeder.half_pools(count).first.include?(pool)
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
      expect(described_class.order(4)).to eq [1, 2, 4, 3]
      expect(described_class.order(5)).to eq [1, 3, 5, 4, 2]
      expect(described_class.order(6)).to eq [1, 2, 6, 5, 3, 4]
      expect(described_class.order(8)).to eq [1, 2, 6, 5, 7, 8, 4, 3]
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

    # An odd count leaves the bottom half one pool short, and at three pools it
    # is a single pool: seed 2 takes it, so seed 3 has nowhere to go but the
    # top half. The shape of the tree, not a flaw in the ordering.
    it "puts seed 3 beside seed 1 at three pools, where the bottom half is one pool wide" do
      expect(halves(3)).to eq [true, false, true]
    end
  end

  # The walk both poolers share. SmartPooler and TeamPooler each used to carry
  # their own copy, which is how they drifted apart in the first place (#1312).
  describe ".assign" do
    it "hands out the order's pools, zero-based, in seed order" do
      expect(described_class.assign(4, [4, 4, 4, 4])).to eq [0, 1, 3, 2]
    end

    it "assigns nothing when nothing is seeded" do
      expect(described_class.assign(0, [4, 4])).to eq []
    end

    it "gives each seed its own pool while the pools last" do
      expect(described_class.assign(4, [4, 4, 4, 4]).uniq.size).to eq 4
    end

    # More seeds than pools wraps the order, and a second seed in a pool is
    # fine — overfilling one past its target size is not, because the pooler
    # then has nowhere to put the unseeded.
    it "wraps onto a second round of pools without exceeding a target size" do
      counts = described_class.assign(6, [2, 2, 2, 2]).tally
      expect(counts.values.sum).to eq 6
      expect(counts.values.max).to be <= 2
    end

    it "skips a pool that is already at its target size" do
      # Pool 1 (index 0) holds one team; the order opens on it, so the second
      # seed must skip past rather than overfill it.
      assigned = described_class.assign(3, [1, 2, 2])
      expect(assigned.count(0)).to eq 1
      expect(assigned.size).to eq 3
    end

    it "never exceeds any target size, across a range of shapes" do
      (1..8).each do |pools|
        sizes = Array.new(pools) { 2 }
        described_class.assign(pools * 2, sizes).tally.each do |index, used|
          expect(used).to be <= sizes[index], "#{pools} pools, index #{index}"
        end
      end
    end
  end
end

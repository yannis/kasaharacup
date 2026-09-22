# frozen_string_literal: true

require "rails_helper"

RSpec.describe BracketPositions do
  describe ".spread_order" do
    def order_for(count)
      described_class.spread_order(BracketTree.shape((count / 2.0).ceil, count / 2))
    end

    # Pinned literally: both seeders read this sequence, and a silent change to
    # it would reseed every bracket-only draw and every bye placement at once.
    it "returns the standard layout for each bracket-half size" do
      expect(order_for(1)).to eq [0]
      expect(order_for(2)).to eq [0, 1]
      expect(order_for(4)).to eq [0, 3, 2, 1]
      expect(order_for(8)).to eq [0, 7, 5, 2, 3, 4, 6, 1]
      expect(order_for(16)).to eq [0, 15, 11, 4, 6, 9, 13, 2, 3, 12, 8, 7, 5, 10, 14, 1]
    end

    it "returns no positions for an empty bracket" do
      expect(order_for(0)).to eq []
    end

    it "gives every seed exactly one position" do
      [1, 2, 4, 8, 16, 32, 64, 128].each do |count|
        expect(order_for(count).sort).to eq (0...count).to_a
      end
    end

    # Seed 1 sits at the top, seed 2 at the very bottom, and they meet only in
    # the final — the property the whole layout exists to provide.
    it "sends the top two seeds to opposite ends" do
      [4, 8, 16, 32].each do |count|
        positions = order_for(count)

        expect(positions.first).to eq 0
        expect(positions[1]).to eq count - 1
      end
    end

    # Taking the first N is how callers get N maximally-spread positions, so
    # each prefix has to stay as evenly spread as the bracket allows.
    it "spreads any prefix of the sequence evenly at every depth" do
      [4, 8, 16, 32].each do |count|
        (1..count).each do |taken|
          chosen = order_for(count).first(taken)
          depth = 2
          while depth <= count
            counts = (0...count).each_slice(depth).map { |group| (group & chosen).size }
            expect(counts.max - counts.min).to be <= 1, "count #{count}, first #{taken}, depth #{depth}"
            depth *= 2
          end
        end
      end
    end

    it "orders a ragged tree's positions, most protected first" do
      expect(described_class.spread_order(BracketTree.shape(3, 2))).to eq [0, 4, 3, 2, 1]
    end

    it "uses every position exactly once on a ragged tree" do
      (1..12).each do |count|
        shape = BracketTree.shape((count / 2.0).ceil, count / 2)

        expect(described_class.spread_order(shape).sort).to eq((0...count).to_a), "count #{count}"
      end
    end

    it "has no order for an empty field" do
      expect(described_class.spread_order(nil)).to eq []
    end
  end
end

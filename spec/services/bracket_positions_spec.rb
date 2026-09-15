# frozen_string_literal: true

require "rails_helper"

RSpec.describe BracketPositions do
  describe ".spread_order" do
    # Pinned literally: both seeders read this sequence, and a silent change to
    # it would reseed every bracket-only draw and every bye placement at once.
    it "returns the standard layout for each bracket-half size" do
      expect(described_class.spread_order(1)).to eq [0]
      expect(described_class.spread_order(2)).to eq [0, 1]
      expect(described_class.spread_order(4)).to eq [0, 3, 2, 1]
      expect(described_class.spread_order(8)).to eq [0, 7, 5, 2, 3, 4, 6, 1]
      expect(described_class.spread_order(16)).to eq [0, 15, 11, 4, 6, 9, 13, 2, 3, 12, 8, 7, 5, 10, 14, 1]
    end

    it "returns no positions for an empty bracket" do
      expect(described_class.spread_order(0)).to eq []
    end

    it "gives every seed exactly one position" do
      [1, 2, 4, 8, 16, 32, 64, 128].each do |count|
        expect(described_class.spread_order(count).sort).to eq (0...count).to_a
      end
    end

    # Seed 1 sits at the top, seed 2 at the very bottom, and they meet only in
    # the final — the property the whole layout exists to provide.
    it "sends the top two seeds to opposite ends" do
      [4, 8, 16, 32].each do |count|
        positions = described_class.spread_order(count)

        expect(positions.first).to eq 0
        expect(positions[1]).to eq count - 1
      end
    end

    # Taking the first N is how callers get N maximally-spread positions, so
    # each prefix has to stay as evenly spread as the bracket allows.
    it "spreads any prefix of the sequence evenly at every depth" do
      [4, 8, 16, 32].each do |count|
        (1..count).each do |taken|
          chosen = described_class.spread_order(count).first(taken)
          depth = 2
          while depth <= count
            counts = (0...count).each_slice(depth).map { |group| (group & chosen).size }
            expect(counts.max - counts.min).to be <= 1, "count #{count}, first #{taken}, depth #{depth}"
            depth *= 2
          end
        end
      end
    end

    it "refuses a count that is not a power of two" do
      [3, 5, 6, 7, 9, 12].each do |count|
        expect { described_class.spread_order(count) }.to raise_error(ArgumentError, /power of two/)
      end
    end
  end
end

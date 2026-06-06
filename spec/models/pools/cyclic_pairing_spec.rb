# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pools::CyclicPairing do
  describe ".pairs_for(size)" do
    it "returns one pair for a pool of 2" do
      expect(described_class.pairs_for(2)).to eq([[1, 2]])
    end

    it "returns three pairs for a pool of 3, keeping one fighter in place between consecutive matches" do
      expect(described_class.pairs_for(3)).to eq([[1, 2], [3, 2], [3, 1]])
    end

    it "returns four cyclic pairs for a pool of 4, keeping one fighter in place between consecutive matches" do
      expect(described_class.pairs_for(4)).to eq([[1, 2], [3, 2], [3, 4], [1, 4]])
    end

    it "returns an empty list for pools of 0 or 1" do
      expect(described_class.pairs_for(0)).to eq([])
      expect(described_class.pairs_for(1)).to eq([])
    end
  end
end

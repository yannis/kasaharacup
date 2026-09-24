# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pools::FightOrder do
  describe ".sides_for(size)" do
    it "fights a pool of 3 as 1 <> 2, 1 <> 3, 2 <> 3, [white, red]" do
      expect(described_class.sides_for(3)).to eq [[2, 1], [3, 1], [3, 2]]
    end

    it "puts the pool's first team on the red side" do
      expect(described_class.sides_for(2)).to eq [[2, 1]]
    end

    # Sorted, a pool of 4's cycle ends 2 <> 3, 3 <> 4: team 3 fights twice in
    # a row, and lower-on-red alone would move it from white to red.
    it "keeps a team fighting twice in a row on the same side" do
      expect(described_class.sides_for(4)).to eq [[2, 1], [4, 1], [3, 2], [3, 4]]
    end

    it "returns nothing for a pool of 0 or 1" do
      expect(described_class.sides_for(0)).to eq []
      expect(described_class.sides_for(1)).to eq []
    end
  end
end

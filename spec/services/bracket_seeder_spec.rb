# frozen_string_literal: true

require "rails_helper"

RSpec.describe BracketSeeder do
  def slot(pool, rank)
    BracketSeeder::Slot.new(pool_number: pool, pool_rank: rank, payload: "#{pool}.#{rank}")
  end

  it "returns no pairs for an empty field" do
    expect(described_class.new([]).first_round_pairs).to eq []
  end

  it "gives a single entry a bye (no opponent)" do
    expect(described_class.new([slot(1, 1)]).first_round_pairs).to eq [[slot(1, 1), nil]]
  end

  it "lays out 4 pools × 2 ranks as a cross-pool draw with same-pool ranks split" do
    rank_major = [slot(1, 1), slot(2, 1), slot(3, 1), slot(4, 1),
      slot(1, 2), slot(2, 2), slot(3, 2), slot(4, 2)]
    pairs = described_class.new(rank_major).first_round_pairs

    expect(pairs).to eq([
      [slot(1, 1), slot(3, 2)],
      [slot(2, 1), slot(4, 2)],
      [slot(3, 1), slot(1, 2)],
      [slot(4, 1), slot(2, 2)]
    ])
  end

  it "derives bracket_size as the next power of two" do
    expect(described_class.new([slot(1, 1), slot(2, 1), slot(3, 1)]).bracket_size).to eq 4
  end
end

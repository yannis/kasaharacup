# frozen_string_literal: true

require "rails_helper"

RSpec.describe BracketSeeder do
  def slot(pool, rank)
    BracketSeeder::Slot.new(pool_number: pool, pool_rank: rank, payload: "#{pool}.#{rank}")
  end

  # Rank-major slot list for `pools` pools each sending `ranks` qualifiers —
  # the shape the pooled builder feeds the seeder.
  def field(pools, ranks)
    (1..ranks).flat_map { |rank| (1..pools).map { |pool| slot(pool, rank) } }
  end

  # Round-1 units meet two at a time in round 2; count the byes in each of
  # those round-2 slots.
  def byes_per_round_2_slot(pairs)
    pairs.each_slice(2).map { |units| units.count { |unit| unit && unit.last.nil? } }
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

  describe "bye distribution" do
    it "spreads the byes of a 6-pool, 2-qualifier field so none meet in round 2" do
      pairs = described_class.new(field(6, 2)).first_round_pairs

      expect(byes_per_round_2_slot(pairs)).to all eq 1
    end

    it "spreads byes as evenly as possible across round-2 slots in every field size" do
      wasteful = each_field.reject { |_, pairs| byes_per_round_2_slot(pairs).minmax.then { |lo, hi| hi - lo <= 1 } }

      expect(wasteful.map(&:first)).to eq []
    end

    it "gives a half's byes to its pool winners before any runner-up" do
      impure = each_field.select { |_, pairs| halves(pairs).any? { |half| skips_a_winner?(half) } }

      expect(impure.map(&:first)).to eq []
    end

    it "reads each half in pool-number order when that still spreads the byes" do
      pairs = described_class.new(field(6, 2)).first_round_pairs

      expect(halves(pairs)).to all satisfy { |half| sorted_by_pool?(half) }
    end

    it "keeps byes and fights each in pool-number order in every field size" do
      unsorted = each_field.reject { |_, pairs|
        halves(pairs).all? { |half| half.partition { |unit| unit.last.nil? }.all? { |group| sorted_by_pool?(group) } }
      }

      expect(unsorted.map(&:first)).to eq []
    end

    it "places every entry exactly once in every field size" do
      lossy = each_field.reject { |(pools, ranks), pairs|
        pairs.flatten.compact.map(&:payload).sort == field(pools, ranks).map(&:payload).sort
      }

      expect(lossy.map(&:first)).to eq []
    end

    # The seeder emits the top half's units followed by the bottom half's, and
    # byes are selected per half — so the invariants are per half too.
    def halves(pairs)
      pairs.each_slice(pairs.size / 2).to_a
    end

    def sorted_by_pool?(units)
      keys = units.map { |unit| [unit.first.pool_number, unit.first.pool_rank] }
      keys == keys.sort
    end

    # A runner-up may only hold a bye once every winner in its half has one
    # (a half with more byes than winners has to spill over).
    def skips_a_winner?(half)
      byes = half.select { |unit| unit.last.nil? }
      return false if byes.all? { |unit| unit.first.pool_rank == 1 }

      half.any? { |unit| unit.first.pool_rank == 1 && !unit.last.nil? }
    end

    # [pools, ranks] => round-1 pairs, over every field the seeder is fed in
    # practice, restricted to those that actually have byes to place.
    def each_field
      [1, 2, 3].product((2..16).to_a).filter_map { |ranks, pools|
        seeder = described_class.new(field(pools, ranks))
        pairs = seeder.first_round_pairs
        next if seeder.bracket_size == pools * ranks || pairs.size < 2

        [[pools, ranks], pairs]
      }
    end
  end
end

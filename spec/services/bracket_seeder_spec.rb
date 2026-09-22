# frozen_string_literal: true

require "rails_helper"

RSpec.describe BracketSeeder do
  def slot(pool, rank)
    BracketSeeder::Slot.new(pool_number: pool, pool_rank: rank, payload: "#{pool}.#{rank}")
  end

  # Rank-major slot list for `pools` pools each sending `ranks` qualifiers —
  # the shape both pooled builders feed the seeder.
  def field(pools, ranks)
    (1..ranks).flat_map { |rank| (1..pools).map { |pool| slot(pool, rank) } }
  end

  def draw(pools, ranks = 2)
    described_class.new(field(pools, ranks))
  end

  # "1.1 v 3.2", "1.1 v bye" — how the posters read.
  def render(pairs)
    pairs.map { |first, second| [first&.payload || "bye", second&.payload || "bye"].join(" v ") }
  end

  describe "base cases" do
    it "returns no pairs for an empty field" do
      expect(described_class.new([]).first_round_pairs).to eq []
      expect(described_class.new([]).tree_shape).to be_nil
    end

    it "gives a single entry a bye" do
      seeder = described_class.new([slot(1, 1)])

      expect(seeder.first_round_pairs).to eq [[slot(1, 1), nil]]
      expect(seeder.tree_shape).to eq 0
    end

    # Two entries are one final, not two byes feeding one — the halving stops
    # before it can hand each half a bye.
    it "draws a two-entry field as a single unit" do
      seeder = described_class.new([slot(1, 1), slot(1, 2)])

      expect(seeder.first_round_pairs).to eq [[slot(1, 1), slot(1, 2)]]
      expect(seeder.tree_shape).to eq 0
    end
  end

  # The 2025 Ladies category, exactly as the organizers drew it. This is the
  # rule's reason to exist; if it drifts, the tool has stopped reproducing the
  # poster.
  describe "the 2025 Ladies bracket (9 pools, 18 qualifiers)" do
    it "draws both halves in ascending pool order with one bye each" do
      expect(render(draw(9).first_round_pairs)).to eq [
        "1.1 v bye", "2.1 v 3.2", "4.1 v 5.2", "6.1 v 7.2", "8.1 v 9.2",
        "1.2 v 2.2", "3.1 v 4.2", "5.1 v 6.2", "7.1 v 8.2", "9.1 v bye"
      ]
    end

    it "builds the poster's tree" do
      expect(draw(9).tree_shape).to eq [
        [[[0, 1], 2], [3, 4]],
        [[5, 6], [7, [8, 9]]]
      ]
    end
  end

  describe "bye counts" do
    # The table in the design spec's Problem section. Byes exist exactly when
    # the pool count is odd, one per half — never the 14 the padded tree drew
    # for the Ladies category.
    it "draws at most one bye per half" do
      counts = [5, 6, 7, 9, 10, 12].index_with { |pools|
        draw(pools).first_round_pairs.count { |pair| pair.compact.size == 1 }
      }

      expect(counts).to eq({5 => 2, 6 => 0, 7 => 2, 9 => 2, 10 => 0, 12 => 0})
    end

    it "gives a field of 18 qualifiers 8 round-1 fights rather than 2" do
      expect(draw(9).first_round_pairs.count { |pair| pair.compact.size == 2 }).to eq 8
    end
  end

  describe "the guarantees" do
    (2..16).each do |pools|
      context "with #{pools} pools" do
        let(:pairs) { draw(pools).first_round_pairs }
        let(:top_half) { pairs.first(pairs.size / 2) }
        let(:bottom_half) { pairs.last(pairs.size / 2) }
        let(:halves) { [top_half, bottom_half] }

        it "places every qualifier exactly once" do
          expect(pairs.flatten.compact.map(&:payload).sort).to eq field(pools, 2).map(&:payload).sort
        end

        it "splits each pool's two qualifiers across the halves" do
          expect(top_half.flatten.compact.map(&:pool_number).sort).to eq (1..pools).to_a
        end

        it "gives every bye to a pool winner" do
          bye_holders = pairs.filter_map { |pair| pair.compact.first if pair.compact.size == 1 }

          expect(bye_holders.map(&:pool_rank)).to all eq(1)
        end

        it "reads each half down in ascending pool order" do
          halves.each do |half|
            pools_down = half.flatten.compact.map(&:pool_number)
            expect(pools_down).to eq pools_down.sort
          end
        end

        it "never lets two byes meet before the final" do
          halves.each do |half|
            expect(half.count { |pair| pair.compact.size == 1 }).to be <= 1
          end
        end
      end
    end
  end

  describe ".half_pools" do
    it "splits the pools whose winner sits in each half" do
      expect(described_class.half_pools(4)).to eq [[1, 3], [2, 4]]
      expect(described_class.half_pools(9)).to eq [[1, 2, 4, 6, 8], [3, 5, 7, 9]]
    end

    it "agrees with the draw it describes, for every pool count" do
      (2..16).each do |pools|
        top, = described_class.half_pools(pools)
        pairs = draw(pools).first_round_pairs
        drawn_top = pairs.first(pairs.size / 2).flatten.compact
          .filter_map { |slot| slot.pool_number if slot.pool_rank == 1 }

        expect(drawn_top.sort).to eq(top), "pool count #{pools}"
      end
    end
  end

  # out_of_pool other than 2 is out of scope for the poster rule; this records
  # what it does rather than leaving it to be discovered.
  describe "a category with three qualifiers per pool" do
    it "alternates the halves by pool ordinal and rank" do
      expect(render(draw(4, 3).first_round_pairs)).to eq [
        "1.1 v 3.1", "2.2 v 4.2", "1.3 v 3.3",
        "2.1 v 4.1", "1.2 v 3.2", "2.3 v 4.3"
      ]
    end

    it "still places every qualifier exactly once, for a range of shapes" do
      (1..5).to_a.product([3, 4]).each do |pools, ranks|
        pairs = described_class.new(field(pools, ranks)).first_round_pairs

        expect(pairs.flatten.compact.map(&:payload).sort).to eq(field(pools, ranks).map(&:payload).sort),
          "#{pools} pools x #{ranks} ranks"
      end
    end
  end
end

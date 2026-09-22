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

  # The organizers drew the 2025 Ladies category compactly: 5 units a half,
  # 2 byes and 8 round-1 fights, accepting that two of its winners then wait out
  # a round. The tool deliberately does not reproduce it. Padding every half to
  # a power of two is what guarantees nobody ever waits, and at nine pools that
  # costs 14 byes and 2 fights. Recorded so a later change cannot quietly claim
  # the sheet is reproduced.
  # Transcribed from the organizers' 2025 sheets, not from our own output — a
  # golden master regenerated from the implementation pins nothing.
  describe "the 2025 posters" do
    it "reproduces the U12 bracket exactly (4 pools, 8 qualifiers)" do
      expect(render(draw(4).first_round_pairs)).to eq [
        "1.1 v 2.2", "3.1 v 4.2",
        "1.2 v 2.1", "3.2 v 4.1"
      ]
      expect(draw(4).tree_shape).to eq [[0, 1], [2, 3]]
    end

    it "reproduces the U15 bracket exactly (7 pools, 14 qualifiers)" do
      expect(render(draw(7).first_round_pairs)).to eq [
        "1.1 v bye", "2.1 v 3.2", "4.1 v 5.2", "6.1 v 7.2",
        "1.2 v 2.2", "3.1 v 4.2", "5.1 v 6.2", "7.1 v bye"
      ]
      expect(draw(7).tree_shape).to eq [[[0, 1], [2, 3]], [[4, 5], [6, 7]]]
    end

    # U18's bottom half runs pools 1, 3, 2, 4, 5, 6 rather than ascending — a
    # hand adjustment the tool does not copy. It does now match the sheet's
    # SHAPE: four units a half, every bye on a pool winner.
    it "matches the U18 sheet's shape but not its hand-adjusted order" do
      pairs = draw(6).first_round_pairs
      poster = ["1.1 v bye", "2.2 v 3.1", "4.2 v 5.2", "6.1 v bye",
        "1.2 v 3.2", "2.1 v bye", "4.1 v bye", "5.1 v 6.2"]

      expect(pairs.size).to eq 8
      expect(pairs.count { |pair| pair.compact.size == 1 }).to eq 4
      expect(pairs.filter_map { |pair| pair.compact.first.pool_rank if pair.compact.size == 1 })
        .to all eq(1)
      expect(render(pairs)).not_to eq poster
    end

    # The 2025 Open was 31 pools drawn across four sheets as one 32-unit tree.
    # Padding reaches the same size; the pool ORDER differs, because the sheets
    # group pools eight to a quarter while the rule reads them down the column.
    it "reaches the Open sheet's size at 31 pools without copying its order" do
      pairs = draw(31).first_round_pairs

      expect(pairs.size).to eq 32
      expect(pairs.count { |pair| pair.compact.size == 1 }).to eq 2
      expect(render(pairs).first).to eq "1.1 v bye"
    end
  end

  describe "the 2025 Ladies bracket (9 pools, 18 qualifiers)" do
    let(:poster) {
      ["1.1 v bye", "2.1 v 3.2", "4.1 v 5.2", "6.1 v 7.2", "8.1 v 9.2",
        "1.2 v 2.2", "3.1 v 4.2", "5.1 v 6.2", "7.1 v 8.2", "9.1 v bye"]
    }

    it "does not reproduce the compact sheet the organizers drew" do
      expect(render(draw(9).first_round_pairs)).not_to eq poster
    end

    it "pads it instead, so that no winner waits a round" do
      pairs = draw(9).first_round_pairs

      expect(pairs.size).to eq 16
      expect(pairs.count { |pair| pair.compact.size == 1 }).to eq 14
    end
  end

  describe "padding" do
    # Every half is padded to a power-of-two unit count, which makes it a
    # perfect tree. Byes absorb the awkward field sizes, and cost more at some
    # counts than others.
    it "pads every half to a power-of-two unit count" do
      counts = [5, 6, 7, 9, 10, 12].index_with { |pools|
        draw(pools).first_round_pairs.count { |pair| pair.compact.size == 1 }
      }

      expect(counts).to eq({5 => 6, 6 => 4, 7 => 2, 9 => 14, 10 => 12, 12 => 8})
    end

    # The guarantee the padding exists for, and the one every poster keeps: a
    # competitor may sit out round 1, but never a later one.
    it "never lets a winner wait out a round, at any pool count" do
      waiting = (2..40).reject { |pools|
        nodes = 0
        walk = lambda do |shape|
          next 1 if shape.is_a?(Integer)

          rounds = shape.map { |part| walk.call(part) }
          nodes += 1 if rounds.uniq.size > 1
          rounds.max + 1
        end
        walk.call(draw(pools).tree_shape)
        nodes.zero?
      }

      expect(waiting).to eq []
    end
  end

  describe "byes" do
    # A perfect half needs 2u - P byes, and at some field sizes that is more
    # byes than the half has pool winners to hand them to: nine pools want 7 a
    # half out of 9 pools. There a bye falls on a runner-up, and two byes have
    # to share a node. Everywhere else both guarantees hold.
    it "gives every bye to a pool winner except where byes outnumber the winners" do
      spilled = (2..16).reject { |pools|
        draw(pools).first_round_pairs.select { |pair| pair.compact.size == 1 }
          .all? { |pair| pair.compact.first.pool_rank == 1 }
      }

      expect(spilled).to eq [5, 9, 10, 11]
    end

    it "keeps two byes off one node except where byes outnumber the pairings" do
      crowded = (2..16).reject { |pools|
        seeder = draw(pools)
        units = seeder.first_round_pairs
        shared = []
        walk = lambda do |shape|
          next units[shape].compact.size == 1 if shape.is_a?(Integer)

          shared << shape if shape.map { |part| walk.call(part) }.all?(true)
          false
        end
        walk.call(seeder.tree_shape)
        shared.empty?
      }

      expect(crowded).to eq [5, 9, 10, 11]
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

        it "reads each half down in ascending pool order" do
          halves.each do |half|
            pools_down = half.flatten.compact.map(&:pool_number)
            expect(pools_down).to eq pools_down.sort
          end
        end
      end
    end
  end

  describe ".half_pools" do
    it "splits the pools whose winner sits in each half" do
      expect(described_class.half_pools(4)).to eq [[1, 3], [2, 4]]
      expect(described_class.half_pools(9)).to eq [[1, 4, 5, 6, 7, 8, 9], [2, 3]]
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

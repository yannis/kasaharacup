# frozen_string_literal: true

require "rails_helper"

RSpec.describe IndividualCategoryBracketBuilder do
  let(:cup) { create(:cup) }
  let(:category) { create(:individual_category, cup: cup, pool_size: 3, out_of_pool: 2) }

  describe "#call" do
    context "with 4 pools fully ranked" do
      let!(:p1_1) { create_qualified_participation(pool_number: 1, pool_rank: 1) }
      let!(:p1_2) { create_qualified_participation(pool_number: 1, pool_rank: 2) }
      let!(:p2_1) { create_qualified_participation(pool_number: 2, pool_rank: 1) }
      let!(:p2_2) { create_qualified_participation(pool_number: 2, pool_rank: 2) }
      let!(:p3_1) { create_qualified_participation(pool_number: 3, pool_rank: 1) }
      let!(:p3_2) { create_qualified_participation(pool_number: 3, pool_rank: 2) }
      let!(:p4_1) { create_qualified_participation(pool_number: 4, pool_rank: 1) }
      let!(:p4_2) { create_qualified_participation(pool_number: 4, pool_rank: 2) }

      it "places R1 fights via canonical 1-vs-N seeding" do
        fights = described_class.new(category).call
        round_one = fights.select { |f| f.round == 1 }.sort_by(&:position)

        expect(round_one.map { |f| [f.fighter_1, f.fighter_2] }).to eq([
          [p1_1.kenshi, p4_2.kenshi],
          [p4_1.kenshi, p1_2.kenshi],
          [p2_1.kenshi, p3_2.kenshi],
          [p3_1.kenshi, p2_2.kenshi]
        ])
      end

      it "wires round 2 fights to their parents in canonical bracket order" do
        fights = described_class.new(category).call
        round_one = fights.select { |f| f.round == 1 }.sort_by(&:position)
        round_two = fights.select { |f| f.round == 2 }.sort_by(&:position)
        final = fights.find { |f| f.round == 3 }

        expect(round_two.first.parent_fight_1).to eq round_one[0]
        expect(round_two.first.parent_fight_2).to eq round_one[1]
        expect(round_two.last.parent_fight_1).to eq round_one[2]
        expect(round_two.last.parent_fight_2).to eq round_one[3]
        expect(final.parent_fight_1).to eq round_two.first
        expect(final.parent_fight_2).to eq round_two.last
      end
    end

    context "with no pool ranks recorded yet" do
      before do
        2.times { |i| create(:participation, category: category, pool_number: 1, pool_position: i + 1) }
        2.times { |i| create(:participation, category: category, pool_number: 2, pool_position: i + 1) }
      end

      it "still generates the full bracket structure with empty fighter slots" do
        fights = described_class.new(category).call

        expect(fights.size).to eq 3
        round_one = fights.select { |f| f.round == 1 }
        expect(round_one.size).to eq 2
        expect(round_one.flat_map { |f| [f.fighter_1_id, f.fighter_2_id] }).to all(be_nil)
      end

      it "records the slot identity (pool_number, pool_rank) on each R1 fighter slot" do
        fights = described_class.new(category).call
        round_one = fights.select { |f| f.round == 1 }
        slot_pairs = round_one.flat_map { |f|
          [[f.fighter_1_pool_number, f.fighter_1_pool_rank], [f.fighter_2_pool_number, f.fighter_2_pool_rank]]
        }

        expect(slot_pairs).to contain_exactly([1, 1], [2, 2], [2, 1], [1, 2])
      end
    end

    context "with partial pool ranks recorded" do
      let!(:p1_1) { create_qualified_participation(pool_number: 1, pool_rank: 1) }
      let!(:p2_1) { create_qualified_participation(pool_number: 2, pool_rank: 1) }

      before do
        create(:participation, category: category, pool_number: 1, pool_position: 2)
        create(:participation, category: category, pool_number: 2, pool_position: 2)
      end

      it "fills in the slots whose pool_rank is known and leaves the rest empty" do
        fights = described_class.new(category).call
        round_one = fights.select { |f| f.round == 1 }.sort_by(&:position)

        expect(round_one.first.fighter_1).to eq p1_1.kenshi
        expect(round_one.first.fighter_2).to be_nil
        expect(round_one.last.fighter_1).to eq p2_1.kenshi
        expect(round_one.last.fighter_2).to be_nil
      end
    end

    context "rebuilding when pool ranks become known" do
      let!(:p1_1) { create_qualified_participation(pool_number: 1, pool_rank: 1) }
      let!(:p1_2) { create(:participation, category: category, pool_number: 1, pool_position: 2) }
      let!(:p2_1) { create_qualified_participation(pool_number: 2, pool_rank: 1) }
      let!(:p2_2) { create(:participation, category: category, pool_number: 2, pool_position: 2) }

      it "fills in newly-resolved slots without destroying existing fights" do
        described_class.new(category).call
        fight_ids_before = category.fights.order(:id).pluck(:id)
        p1_2.update!(pool_rank: 2)
        p2_2.update!(pool_rank: 2)

        described_class.new(category).call

        expect(category.fights.order(:id).pluck(:id)).to eq fight_ids_before
        round_one = category.fights.where(round: 1).order(:position)
        expect(round_one.first.fighter_2).to eq p2_2.kenshi
        expect(round_one.last.fighter_2).to eq p1_2.kenshi
      end

      it "preserves recorded winners when filling in new slots" do
        described_class.new(category).call
        recorded = category.fights.where(round: 1).order(:position).first
        recorded.update!(winner: recorded.fighter_1)
        p1_2.update!(pool_rank: 2)
        p2_2.update!(pool_rank: 2)

        described_class.new(category).call

        expect(recorded.reload.winner).to eq recorded.fighter_1
      end
    end

    context "with out_of_pool greater than 2" do
      let(:category) { create(:individual_category, cup: cup, pool_size: 4, out_of_pool: 3) }

      before do
        (1..4).each do |pool_number|
          (1..3).each do |pool_rank|
            create_qualified_participation(pool_number: pool_number, pool_rank: pool_rank)
          end
        end
      end

      it "uses qualifiers from every pool rank up to out_of_pool" do
        fights = described_class.new(category).call
        round_one = fights.select { |f| f.round == 1 }
        all_ranks = round_one.flat_map { |f| [f.fighter_1_pool_rank, f.fighter_2_pool_rank] }.compact

        expect(all_ranks).to contain_exactly(1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3)
      end
    end

    describe "rank-1 fighters never face each other in round 1" do
      [
        {pool_count: 1, out_of_pool: 2},
        {pool_count: 2, out_of_pool: 2},
        {pool_count: 3, out_of_pool: 2},
        {pool_count: 4, out_of_pool: 2},
        {pool_count: 5, out_of_pool: 2},
        {pool_count: 6, out_of_pool: 2},
        {pool_count: 8, out_of_pool: 2},
        {pool_count: 2, out_of_pool: 3},
        {pool_count: 4, out_of_pool: 3},
        {pool_count: 5, out_of_pool: 3}
      ].each do |scenario|
        it "holds for #{scenario[:pool_count]} pools with out_of_pool=#{scenario[:out_of_pool]}" do
          category = create(:individual_category, cup: cup, pool_size: 3, out_of_pool: scenario[:out_of_pool])
          (1..scenario[:pool_count]).each do |pool_number|
            (1..scenario[:out_of_pool]).each do |pool_rank|
              create(:participation,
                category: category,
                pool_number: pool_number,
                pool_position: pool_rank,
                pool_rank: pool_rank)
            end
          end

          fights = described_class.new(category).call
          round_one = fights.select { |f| f.round == 1 }
          rank_one_vs_rank_one = round_one.select { |f|
            f.fighter_1_pool_rank == 1 && f.fighter_2_pool_rank == 1
          }

          expect(rank_one_vs_rank_one).to be_empty
        end
      end
    end

    it "does not build a bracket when no participations have a pool number" do
      expect(described_class.new(category).call).to eq []
      expect(category.fights).to be_empty
    end

    it "incorporates newly qualifying ranks when out_of_pool grows between calls" do
      narrow_category = create(:individual_category, cup: cup, pool_size: 3, out_of_pool: 1)
      create(:participation, category: narrow_category, pool_number: 1, pool_position: 1, pool_rank: 1)
      create(:participation, category: narrow_category, pool_number: 2, pool_position: 1, pool_rank: 1)
      described_class.new(narrow_category).call
      expect(narrow_category.fights.where(round: 1).count).to eq 1

      narrow_category.update!(out_of_pool: 2)
      create(:participation, category: narrow_category, pool_number: 1, pool_position: 2, pool_rank: 2)
      create(:participation, category: narrow_category, pool_number: 2, pool_position: 2, pool_rank: 2)

      described_class.new(narrow_category, rebuild_started: true).call

      round_one = narrow_category.fights.where(round: 1)
      expect(round_one.count).to eq 2
      slot_ranks = round_one.flat_map { |f| [f.fighter_1_pool_rank, f.fighter_2_pool_rank] }.compact
      expect(slot_ranks).to contain_exactly(1, 1, 2, 2)
    end

    it "rebuilds destructively when rebuild_started: true is passed" do
      create_qualified_participation(pool_number: 1, pool_rank: 1)
      create_qualified_participation(pool_number: 1, pool_rank: 2)
      create_qualified_participation(pool_number: 2, pool_rank: 1)
      create_qualified_participation(pool_number: 2, pool_rank: 2)
      described_class.new(category).call
      first_fight = category.fights.bracket_order.first
      first_fight.update!(winner: first_fight.fighter_1)

      described_class.new(category, rebuild_started: true).call

      expect(category.fights.where.not(winner_id: nil)).to be_empty
    end
  end

  def create_qualified_participation(pool_number:, pool_rank:)
    create(:participation,
      category: category,
      pool_number: pool_number,
      pool_position: pool_rank,
      pool_rank: pool_rank)
  end
end

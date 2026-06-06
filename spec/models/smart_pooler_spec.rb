# frozen_string_literal: true

require "rails_helper"

RSpec.describe SmartPooler do
  let!(:cup) { create(:cup) }
  let(:pool_size) { 4 }
  let(:category) {
    create(:individual_category, name: "open", pool_size: pool_size, out_of_pool: 2, cup: cup)
  }

  # Endless counter giving each kenshi unique names so validations never collide.
  let(:sequence) { (1..).each }

  # Creates one participation with a kenshi of the given grade/club.
  def add_participant(grade: "kyu", club: nil)
    n = sequence.next
    club ||= create(:club)
    kenshi = create(:kenshi, cup: cup, grade: grade, club: club,
      first_name: "First#{n}", last_name: "Last#{n}")
    create(:participation, category: category, kenshi: kenshi)
  end

  # {pool_number => [participations]} read fresh from the database.
  def pooled
    category.participations.includes(:kenshi).where.not(pool_number: nil).group_by(&:pool_number)
  end

  def pool_number_by_kenshi
    category.participations.where.not(pool_number: nil)
      .each_with_object({}) { |p, h| h[p.kenshi_id] = p.pool_number }
  end

  # Sorted pool numbers of the short pools (fewer than pool_size participants).
  def short_pool_numbers
    pooled.select { |_number, participations| participations.size < pool_size }.keys.sort
  end

  describe "#set_pools" do
    context "pool sizing with 13 participants and pool_size 4" do
      let(:pool_size) { 4 }

      before do
        13.times { add_participant }
        described_class.new(category).set_pools
      end

      it "creates ceil(N / pool_size) pools" do
        expect(pooled.keys.sort).to eq [1, 2, 3, 4]
      end

      it "never exceeds pool_size and keeps sizes within one of each other" do
        sizes = pooled.values.map(&:size)
        expect(sizes.max).to be <= pool_size
        expect(sizes.max - sizes.min).to be <= 1
      end

      it "fills every participant into exactly one pool" do
        expect(pooled.values.sum(&:size)).to eq 13
      end
    end

    # Short pools head the bracket's halves/quarters rather than clustering at
    # the top, so the byes/easier pools are spread evenly across the bracket.
    context "spreading short pools across the bracket" do
      context "with 2 short pools among 8" do
        let(:pool_size) { 4 }

        before do
          30.times { add_participant } # 8 pools: 6 of size 4, 2 of size 3
          described_class.new(category).set_pools
        end

        it "heads each half (pools #1 and #5)" do
          expect(short_pool_numbers).to eq [1, 5]
        end
      end

      context "with 4 short pools among 8" do
        let(:pool_size) { 5 }

        before do
          36.times { add_participant } # 8 pools: 4 of size 5, 4 of size 4
          described_class.new(category).set_pools
        end

        it "heads each quarter (pools #1, #3, #5 and #7)" do
          expect(short_pool_numbers).to eq [1, 3, 5, 7]
        end
      end
    end

    context "club separation when each club fits within the pool count" do
      let(:pool_size) { 4 }

      before do
        shared = create(:club)
        2.times { add_participant(club: shared) } # two pools, two members -> splittable
        6.times { add_participant }
        described_class.new(category).set_pools
      end

      it "never places two members of the same club in one pool" do
        pooled.each_value do |participations|
          club_ids = participations.map { |p| p.kenshi.club_id }
          expect(club_ids).to eq club_ids.uniq
        end
      end
    end

    context "club separation when a club has more members than pools" do
      let(:pool_size) { 3 }
      let!(:big_club) { create(:club) }

      before do
        3.times { add_participant(club: big_club) } # 3 members, only 2 pools
        3.times { add_participant }
        described_class.new(category).set_pools
      end

      it "spreads the club as evenly as possible across pools" do
        per_pool = pooled.values.map { |ps| ps.count { |p| p.kenshi.club_id == big_club.id } }
        expect(per_pool.max).to be <= 2 # ceil(3 members / 2 pools)
      end
    end

    context "grade homogeneity with strong and weak fighters" do
      let(:pool_size) { 4 }

      before do
        2.times { add_participant(grade: "5Dan") }
        6.times { add_participant(grade: "kyu") }
        described_class.new(category).set_pools
      end

      it "separates the strongest fighters across pools" do
        strong = category.participations.includes(:kenshi).select { |p| p.kenshi.grade == "5Dan" }
        expect(strong.map(&:pool_number).uniq.size).to eq 2
      end

      it "balances total strength across pools" do
        totals = pooled.values.map { |ps| ps.sum { |p| p.kenshi.grade.to_i } }
        expect(totals.max - totals.min).to be <= 5
      end
    end

    context "determinism with an injected RNG" do
      let(:pool_size) { 3 }

      before do
        9.times { |i| add_participant(grade: %w[kyu 1Dan 2Dan][i % 3]) }
      end

      it "produces the same assignment for the same seed" do
        described_class.new(category, random: Random.new(123)).set_pools
        first = pool_number_by_kenshi
        described_class.new(category, random: Random.new(123)).set_pools
        expect(pool_number_by_kenshi).to eq first
      end
    end

    context "when pool_size is 1" do
      let(:pool_size) { 1 }

      before do
        4.times { add_participant }
        described_class.new(category).set_pools
      end

      it "assigns no pools" do
        expect(category.participations.where.not(pool_number: nil)).to be_empty
      end
    end

    context "when there are no participants" do
      it "does nothing without error" do
        expect { described_class.new(category).set_pools }.not_to raise_error
      end
    end

    context "re-pooling after pools already exist" do
      let(:pool_size) { 3 }

      before { 6.times { add_participant } }

      it "clears stale pool assignments when pooling is disabled" do
        described_class.new(category).set_pools
        expect(pooled).not_to be_empty
        category.update!(pool_size: 1)
        described_class.new(category).set_pools
        expect(category.participations.where.not(pool_number: nil)).to be_empty
      end
    end

    context "backwards compatibility: 24 participants, pool_size 3" do
      let(:pool_size) { 3 }

      before do
        24.times { add_participant }
        described_class.new(category).set_pools
      end

      it "creates 8 pools" do
        expect(category.pools.size).to eq 8
      end
    end
  end
end

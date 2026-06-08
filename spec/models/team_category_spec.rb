# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamCategory do
  describe "Associations" do
    let(:team_category) { create(:team_category) }

    it do
      expect(team_category).to belong_to :cup
      expect(team_category).to have_many(:fights).dependent(:destroy)
      expect(team_category).to have_many(:participations).dependent(:destroy)
      expect(team_category).to have_many(:documents).dependent(:destroy)
      expect(team_category).to have_many(:videos).dependent(:destroy)
      expect(team_category).to have_many(:kenshis).through(:teams)

      expect(team_category).to respond_to :name
      expect(team_category).to respond_to :pool_size
      expect(team_category).to respond_to :out_of_pool
      expect(team_category).to respond_to :pools
      expect(team_category).to respond_to :fights
      expect(team_category).to respond_to :data
      expect(team_category).to respond_to :min_age
      expect(team_category).to respond_to :max_age
      expect(team_category).to respond_to :description
      expect(team_category).to respond_to :year

      expect(team_category).to validate_presence_of :cup_id
      expect(team_category).to validate_presence_of :name
      expect(team_category).to validate_uniqueness_of(:name).scoped_to(:cup_id)
    end
  end

  describe "#bracket_encounters" do
    it "returns only encounters with no pool_number" do
      tc = create(:team_category)
      a = create(:team, team_category: tc)
      b = create(:team, team_category: tc)
      pool = create(:encounter, team_category: tc, team_1: a, team_2: b, pool_number: 1)
      bracket = create(:encounter, team_category: tc, team_1: a, team_2: b, round: 1, position: 1)

      expect(tc.bracket_encounters).to include(bracket)
      expect(tc.bracket_encounters).not_to include(pool)
    end
  end

  describe "Validations" do
    let(:cup) { create(:cup) }

    it "accepts nil gender_restriction (open category)" do
      expect(build(:team_category, cup: cup, gender_restriction: nil)).to be_valid
    end

    it "accepts \"female\" gender_restriction" do
      expect(build(:team_category, cup: cup, gender_restriction: "female")).to be_valid
    end

    it "accepts \"male\" gender_restriction" do
      expect(build(:team_category, cup: cup, gender_restriction: "male")).to be_valid
    end

    it "raises on an unknown gender_restriction value" do
      expect {
        build(:team_category, cup: cup, gender_restriction: "other")
      }.to raise_error(ArgumentError, /not a valid gender_restriction/)
    end
  end

  describe "team_size" do
    let(:cup) { create(:cup) }

    it "defaults team_size to 5" do
      expect(build(:team_category).team_size).to eq 5
    end

    it "accepts a team_size of 3 or 5" do
      expect(build(:team_category, cup: cup, team_size: 3)).to be_valid
      expect(build(:team_category, cup: cup, team_size: 5)).to be_valid
    end

    it "rejects any other team_size" do
      expect(build(:team_category, cup: cup, team_size: 4)).not_to be_valid
    end
  end

  describe "A team_category team" do
    let!(:team_category) {
      create(:team_category, name: "team", pool_size: 3, out_of_pool: 2,
        cup: create(:cup, start_on: Date.parse("2016-09-28")))
    }

    it { expect(team_category).to be_valid_verbose }
    it { expect(team_category.name).to eql "team" }
    it { expect(team_category.full_name).to eql "team (#{team_category.cup.year})" }
    it { expect(team_category.year).to be 2016 }

    context "with a pool of 3 participations" do
      let!(:participation1) {
        create(:participation, category: team_category, pool_number: 1, pool_position: 1,
          kenshi: create(:kenshi, cup: team_category.cup))
      }
      let!(:participation2) {
        create(:participation, category: team_category, pool_number: 1, pool_position: 2,
          kenshi: create(:kenshi, cup: team_category.cup))
      }
      let!(:participation3) {
        create(:participation, category: team_category, pool_number: 1, pool_position: 3,
          kenshi: create(:kenshi, cup: team_category.cup))
      }

      it { expect(participation1).to be_valid_verbose }
      it { expect(participation1.category).to eql team_category }
      it { expect(team_category.pools.size).to eq 1 }
      it { expect(team_category.participations.size).to eq 3 }
    end

    context "with 24 participations" do
      before {
        24.times do |i|
          kenshi = create(:kenshi, first_name: "fn_#{i}", last_name: "ln_#{i}", cup: team_category.cup)
          create(:participation, category_type: "TeamCategory", category_id: team_category.id,
            kenshi: kenshi)
        end
        team_category.reload
      }

      it { expect(team_category.participations.count).to eq 24 }
      it { expect(team_category.pools.size).to eq 0 }

      context "when pools are generated" do
        before { team_category.set_smart_pools }

        it { expect(team_category.pools.size).to eq 8 }
      end
    end
  end

  describe "#team_pools" do
    it "groups teams by pool_number, ordered by pool_position, ignoring unpooled teams" do
      tc = create(:team_category, pool_size: 3)
      a = create(:team, team_category: tc, pool_number: 1, pool_position: 2)
      b = create(:team, team_category: tc, pool_number: 1, pool_position: 1)
      c = create(:team, team_category: tc, pool_number: 2, pool_position: 1)
      create(:team, team_category: tc) # unpooled

      pools = tc.team_pools
      expect(pools.map(&:number)).to eq [1, 2]
      expect(pools.first.teams).to eq [b, a]
      expect(pools.last.teams).to eq [c]
    end
  end
end

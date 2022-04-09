# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamCategory do
  it { is_expected.to belong_to :cup }
  it { is_expected.to have_many(:fights).dependent(:destroy) }
  it { is_expected.to have_many(:participations).dependent(:destroy) }
  it { is_expected.to have_many(:documents).dependent(:destroy) }
  it { is_expected.to have_many(:videos).dependent(:destroy) }
  it { is_expected.to have_many(:kenshis).through(:teams) }

  it { is_expected.to respond_to :name }
  it { is_expected.to respond_to :pool_size }
  it { is_expected.to respond_to :out_of_pool }
  it { is_expected.to respond_to :pools }
  it { is_expected.to respond_to :fights }
  it { is_expected.to respond_to :tree }
  it { is_expected.to respond_to :min_age }
  it { is_expected.to respond_to :max_age }
  it { is_expected.to respond_to :description }
  it { is_expected.to respond_to :year }

  it { is_expected.to validate_presence_of :cup_id }
  it { is_expected.to validate_presence_of :name }
  it { is_expected.to validate_uniqueness_of(:name).scoped_to(:cup_id) }

  describe "A team_category team", type: :model do
    let!(:team_category) {
      create :team_category, name: "team", pool_size: 3, out_of_pool: 2,
        cup: create(:cup, start_on: Date.parse("2016-09-28"))
    }

    it { expect(team_category).to be_valid_verbose }
    it { expect(team_category.name).to eql "team" }
    it { expect(team_category.full_name).to eql "team (#{team_category.cup.year})" }
    it { expect(team_category.year).to be 2016 }

    context "with a pool of 3 participations" do
      let!(:participation1) {
        create :participation, category: team_category, pool_number: 1, pool_position: 1,
          kenshi: create(:kenshi, cup: team_category.cup)
      }
      let!(:participation2) {
        create :participation, category: team_category, pool_number: 1, pool_position: 2,
          kenshi: create(:kenshi, cup: team_category.cup)
      }
      let!(:participation3) {
        create :participation, category: team_category, pool_number: 1, pool_position: 3,
          kenshi: create(:kenshi, cup: team_category.cup)
      }

      it { expect(participation1).to be_valid_verbose }
      it { expect(participation1.category).to eql team_category }
      it { expect(team_category.pools.size).to eq 1 }
      it { expect(team_category.participations.size).to eq 3 }
    end

    context "with 24 participations" do
      before {
        24.times do |i|
          kenshi = create :kenshi, first_name: "fn_#{i}", last_name: "ln_#{i}", cup: team_category.cup
          create :participation, category_type: "TeamCategory", category_id: team_category.id,
            kenshi: kenshi
        end
        team_category.reload
      }

      it { expect(team_category.participations.count).to eq 24 }
      it { expect(team_category.pools.size).to eq 0 }

      context "when pools are generated" do
        before { team_category.set_smart_pools }

        it { expect(team_category.pools.size).to eq 8 }
        # it {expect(team_category.tree).to be_a Tree}
        # it {expect(team_category.data).to be_a Hash}
        # it {expect(team_category.data.keys).to eq [:tree]}
        # it {expect(team_category.data[:tree].keys).to eq [:elements, :depth, :branch_number]}
      end
    end
  end
end

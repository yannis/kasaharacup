# frozen_string_literal: true

require "rails_helper"

RSpec.describe Kenshi, type: :model do
  let(:cup) { create :cup, start_on: 10.years.since }

  describe "Attributes" do
    let(:kenshi) { build(:kenshi) }

    it do
      expect(kenshi).to respond_to :first_name
      expect(kenshi).to respond_to :last_name
      expect(kenshi).to respond_to :dob
      expect(kenshi).to respond_to :club
      expect(kenshi).to respond_to :grade
      expect(kenshi).to respond_to :email
      expect(kenshi).to respond_to :remarks
    end
  end

  describe "Associations" do
    let(:kenshi) { build(:kenshi) }

    it do
      expect(kenshi).to belong_to :cup
      expect(kenshi).to belong_to :user
      expect(kenshi).to belong_to :club
      expect(kenshi).to have_many(:participations).dependent(:destroy)
      expect(kenshi).to have_many(:individual_categories).through(:participations)
      expect(kenshi).to have_many(:teams).through(:participations)
      expect(kenshi).to have_many(:purchases).dependent(:destroy)
      expect(kenshi).to have_many(:products).through(:purchases)
    end
  end

  describe "Validations" do
    let(:kenshi) { create(:kenshi) }

    it do
      expect(kenshi).to validate_presence_of :first_name
      expect(kenshi).to validate_presence_of :last_name
      expect(kenshi).to validate_presence_of :dob
      expect(kenshi).to validate_presence_of :grade
      expect(kenshi).to validate_uniqueness_of(:last_name).scoped_to([:cup_id, :first_name]).case_insensitive
      expect(kenshi).to validate_inclusion_of(:grade).in_array Kenshi::GRADES
      expect(kenshi).to act_as_fighter
    end
  end

  describe "A kenshi" do
    let(:cup) { create :cup, start_on: "#{Date.current.year}-12-29" }
    let(:club) { create :club, name: "Shung Do Kwan" }
    let(:kenshi) {
      create :kenshi, first_name: "Yannis", last_name: "Jaquet", female: false, club: club, dob: 20.years.ago,
        cup: cup
    }

    it { expect(kenshi).to be_valid_verbose }
    it { expect(kenshi.full_name).to eq "Yannis Jaquet" }
    it { expect(kenshi).to be_adult }
    it { expect(kenshi.age_at_cup).to eq 20 }
    it { expect(kenshi.club.name).to eq "Shung Do Kwan" }
    it { expect(kenshi.poster_name).to eq "JAQUET" }

    context "updated as junior" do
      before {
        kenshi.update dob: 12.years.ago
      }

      it { expect(kenshi).to be_junior }
      it { expect(kenshi.age_at_cup).to eq 12 }
    end
  end

  describe "A kenshi with badly formatted name and email" do
    let(:kenshi) {
      create :kenshi, first_name: "FIRST-J.-sébastien mÜhlebäch", last_name: "LAST-J.-name nAme",
        email: "STUPIDLY.FORAMaTTED@EMAIL.COM", cup: cup
    }

    it { expect(kenshi.norm_last_name).to eq "Last-J.-Name Name" }
    it { expect(kenshi.norm_first_name).to eq "First-J.-Sébastien Mühlebäch" }
    it { expect(kenshi.full_name).to eq "First-J.-Sébastien Mühlebäch Last-J.-Name Name" }
    it { expect(kenshi.reload.email).to eq "stupidly.foramatted@email.com" }
  end

  describe "Updating a kenshi with participations data" do
    let(:kenshi) { create :kenshi, first_name: "Yannis", last_name: "Jaquet", female: false, cup: cup }
    let(:individual_category) { create :individual_category, cup: kenshi.cup }
    let(:team_category) { create :team_category, cup: kenshi.cup }

    context "creating a team and an individual participations" do
      before {
        kenshi.update individual_category_ids: [individual_category.id],
          participations_attributes: {"0" => {category_type: "TeamCategory", category_id: team_category.id,
                                              team_name: "sdk1"}}
      }

      it do
        kenshi.participations.all { |participation| expect(participation).to be_valid_verbose }
      end

      it { expect(kenshi.participations.count).to be 2 }

      it {
        expect(kenshi.participations.map { |p|
                 p.category.name
               }).to match_array [individual_category.name, team_category.name]
      }

      it { expect(kenshi.individual_categories.count).to be 1 }
      it { expect(kenshi.takes_part_to?(individual_category)).to be true }
      it { expect(kenshi.competition_fee(:chf)).to be 30 }
      it { expect(kenshi.competition_fee(:eur)).to be 25 }
      it { expect(kenshi).to be_adult }
      it { expect(kenshi.fees(:chf)).to be 30 }
      it { expect(kenshi.fees(:eur)).to be 25 }

      context "with a purchase" do
        let(:product) { create :product, cup: kenshi.cup }

        before {
          kenshi.update product_ids: [product.id]
          # kenshi.reload
        }

        it { expect(kenshi).to be_valid_verbose }

        it { expect(kenshi.products.count).to eq 1 }
        it { expect(kenshi.products_fee(:chf)).to be 10 }
        it { expect(kenshi.products_fee(:eur)).to be 8 }
        it { expect(kenshi.fees(:chf)).to be 40 }
        it { expect(kenshi.fees(:eur)).to be 33 }
        it { expect(kenshi.purchased?(product)).to be true }
      end

      context "and deleting the team participation" do
        before {
          kenshi.update participations_attributes: {"0" => {id: kenshi.participations.first.id,
                                                            _destroy: 1}}
        }

        it { expect(kenshi.participations.count).to eq 1 }
      end
    end
  end

  describe "fitness" do
    context "kenshi aged 20 and 0Dan" do
      let(:kenshi) { build :kenshi, dob: 20.years.ago, grade: "kyu", cup: cup }

      it { expect(kenshi.fitness).to be 0.0 }
    end

    context "kenshi aged 20 and 1Dan" do
      let(:kenshi) { build :kenshi, dob: 20.years.ago, grade: "1Dan", cup: cup }

      it { expect(kenshi.fitness).to be 0.0333 }
    end

    context "kenshi aged 20 and 3Dan" do
      let(:kenshi) { build :kenshi, dob: 20.years.ago, grade: "3Dan", cup: cup }

      it { expect(kenshi.fitness).to be 0.1 }
    end

    context "kenshi aged 60 and 8Dan" do
      let(:kenshi) { build :kenshi, dob: 60.years.ago, grade: "3Dan", cup: cup }

      it { expect(kenshi.fitness).to be 0.0429 }
    end
  end
end

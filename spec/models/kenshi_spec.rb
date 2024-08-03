# frozen_string_literal: true

require "rails_helper"

RSpec.describe Kenshi do
  let(:cup) { create(:cup, :with_cup_products, start_on: "#{Date.current.year}-12-29") }

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
      expect(kenshi).to have_one(:personal_info).dependent(:destroy).inverse_of(:kenshi)
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

  describe "Scopes" do
    describe ".shinpans, .not_shinpans" do
      let(:cup) { create(:cup) }
      let!(:shinpan) { create(:kenshi, shinpan: true, cup: cup) }
      let!(:kenshi) { create(:kenshi, cup: cup) }
      let!(:shinpan_with_participation) { create(:kenshi, shinpan: true, cup: cup) }
      let!(:participation) { create(:participation, kenshi: shinpan_with_participation) }

      it do
        expect(described_class.shinpans).to eq [shinpan]
        expect(described_class.not_shinpans).to contain_exactly(kenshi, shinpan_with_participation)
      end
    end
  end

  describe "Callbacks" do
    describe "after_create_commit" do
      let(:kenshi) { build(:kenshi) }

      it do
        expect(kenshi).to receive(:notify_slack).once
        kenshi.save
      end
    end

    describe "after_commit" do
      describe "#update_purchase" do
        let!(:kenshi) { build(:kenshi, cup: cup) }
        let(:calculate_purchases_service) { instance_double(Kenshis::CalculatePurchasesService) }

        before do
          allow(Kenshis::CalculatePurchasesService).to receive(:new).and_return(calculate_purchases_service)
          allow(calculate_purchases_service).to receive(:call)
        end

        it do
          kenshi.save
          expect(calculate_purchases_service).to have_received(:call).once
        end
      end
    end
  end

  describe "A kenshi" do
    let(:club) { create(:club, name: "Shung Do Kwan") }
    let(:kenshi) do
      create(:kenshi, first_name: "Yannis", last_name: "Jaquet", female: false,
        club: club, dob: 20.years.ago, cup: cup)
    end

    it do
      expect(kenshi).to be_valid_verbose
      expect(kenshi.full_name).to eq "Yannis Jaquet"
      expect(kenshi).to be_adult
      expect(kenshi.age_at_cup).to eq 20
      expect(kenshi.club.name).to eq "Shung Do Kwan"
      expect(kenshi.poster_name).to eq "JAQUET"
    end

    context "when updated as junior" do
      before {
        kenshi.update dob: 12.years.ago
      }

      it { expect(kenshi).to be_junior }
      it { expect(kenshi.age_at_cup).to eq 12 }
    end
  end

  describe "A kenshi with badly formatted name and email" do
    let(:kenshi) {
      create(:kenshi, first_name: "FIRST-J.-sébastien mÜhlebäch", last_name: "LAST-J.-name nAme",
        email: "STUPIDLY.FORAMaTTED@EMAIL.COM", cup: cup)
    }

    it { expect(kenshi.norm_last_name).to eq "Last-J.-Name Name" }
    it { expect(kenshi.norm_first_name).to eq "First-J.-Sébastien Mühlebäch" }
    it { expect(kenshi.full_name).to eq "First-J.-Sébastien Mühlebäch Last-J.-Name Name" }
    it { expect(kenshi.reload.email).to eq "stupidly.foramatted@email.com" }
  end

  describe "Updating a kenshi with participations data" do
    let(:kenshi) { create(:kenshi, first_name: "Yannis", last_name: "Jaquet", female: false, cup: cup) }
    let(:individual_category) { create(:individual_category, cup: kenshi.cup) }
    let(:team_category) { create(:team_category, cup: kenshi.cup) }
    let(:product_individual_adult) { cup.product_individual_adult }
    let(:product_individual_junior) { cup.product_individual_junior }
    let(:product_full_adult) { cup.product_full_adult }
    let(:product_full_junior) { cup.product_full_junior }
    let(:product_team) { cup.product_team }

    context "when creating a team and an individual participations" do
      before do
        kenshi.update(
          individual_category_ids: [individual_category.id],
          participations_attributes: {
            "0" => {category_type: "TeamCategory", category_id: team_category.id, team_name: "sdk1"}
          }
        )
      end

      it do
        kenshi.participations.all { |participation| expect(participation).to be_valid_verbose }
        expect(kenshi.participations.count).to eq(2)
        expect(kenshi.participations.map(&:category)).to contain_exactly(individual_category, team_category)
        expect(kenshi.individual_categories.count).to eq(1)
        expect(kenshi).to be_takes_part_to(individual_category)
        expect(kenshi).to be_takes_part_to(team_category)
        expect(kenshi).to be_adult
        expect(kenshi.fees(:chf)).to eq(product_full_adult.fee_chf)
        expect(kenshi.fees(:eur)).to eq(product_full_adult.fee_eu)
      end

      context "with a purchase" do
        let(:product) { create(:product, cup: kenshi.cup) }

        before { kenshi.update product_ids: [product.id] }

        it do
          kenshi.reload
          expect(kenshi).to be_valid_verbose
          expect(kenshi.products.count).to eq 2
          expect(kenshi.fees(:chf)).to eq(product_full_adult.fee_chf + product.fee_chf)
          expect(kenshi.fees(:eur)).to eq(product_full_adult.fee_eu + product.fee_eu)
          expect(kenshi).to be_takes_part_to(individual_category)
          expect(kenshi).to be_takes_part_to(team_category)
          expect(kenshi).to be_purchased(product)
        end
      end

      context "when deleting the team participation" do
        before do
          kenshi.update participations_attributes: {
            "0" => {id: kenshi.participations.first.id, _destroy: 1}
          }
        end

        it do
          kenshi.reload
          expect(kenshi).to be_valid_verbose
          expect(kenshi.products.count).to eq 1
          expect(kenshi.fees(:chf)).to eq(product_team.fee_chf)
          expect(kenshi.fees(:eur)).to eq(product_team.fee_eu)
          expect(kenshi).to be_takes_part_to(team_category)
          expect(kenshi).not_to be_takes_part_to(individual_category)
        end
      end
    end
  end

  describe "fitness" do
    context "when kenshi aged 20 and 0Dan" do
      let(:kenshi) { build(:kenshi, dob: 20.years.ago, grade: "kyu", cup: cup) }

      it { expect(kenshi.fitness).to eq(0.0) }
    end

    context "when kenshi aged 20 and 1Dan" do
      let(:kenshi) { build(:kenshi, dob: 20.years.ago, grade: "1Dan", cup: cup) }

      it { expect(kenshi.fitness).to eq(0.05) }
    end

    context "when kenshi aged 20 and 3Dan" do
      let(:kenshi) { build(:kenshi, dob: 20.years.ago, grade: "3Dan", cup: cup) }

      it { expect(kenshi.fitness).to eq(0.15) }
    end

    context "when kenshi aged 60 and 8Dan" do
      let(:kenshi) { build(:kenshi, dob: 60.years.ago, grade: "3Dan", cup: cup) }

      it { expect(kenshi.fitness).to eq(0.05) }
    end
  end
end
